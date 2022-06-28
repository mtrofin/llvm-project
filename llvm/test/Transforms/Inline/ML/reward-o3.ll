; RUN: llc -calc-inl-reward --filetype=asm < %s | FileCheck -check-prefix=EXPR %s

; RUN: llc -calc-inl-reward --filetype=obj -o %t.o %s
; RUN: llvm-objcopy --dump-section=.llvm_block_data.=%t.data %t.o /dev/null
; RUN: llvm-objdump -d %t.o | FileCheck -check-prefix=DUMP %s
; RUN: %python %p/Inputs/parse_reward.py %t.data | FileCheck -check-prefix=OBJ %s

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-grtev4-linux-gnu"

declare void @ext();

define i32 @f0(i32 %a1) {
  %add = add i32 %a1, 1
  %cond = icmp sle i32 %add, 1
  br i1 %cond, label %yes, label %no, !prof !1
yes:
  %a2 = call i32 @f1(i32 %add)
  br label %exit
no:
  %a3 = call i32 @f2(i32 %add)
  br label %exit
exit:
  %ret = phi i32 [%a2, %yes], [%a3, %no]
  ret i32 %ret
}

define internal i32 @f1(i32 %c1) {
  call void @ext()
  %cond = icmp sle i32 %c1, 1
  br i1 %cond, label %cond_true, label %cond_false, !prof !2

cond_false:
  br label %exit

cond_true:
  %c11 = call i32 @f2(i32 %c1)
  br label %exit
exit:
  %c12 = phi i32 [ 0, %cond_false], [ %c11, %cond_true ]
  ret i32 %c12
}

define i32 @f2(i32 %c1) {
  call void @ext()
  %cond = icmp sle i32 %c1, 1
  br i1 %cond, label %cond_true, label %cond_false, !prof !3

cond_false:
  %ret = call i32 @f1(i32 2)
  ret i32 %ret

 cond_true:
  ret i32 0
}

define i32 @f3() {
  ret i32 1
}

define i32 @f4() {
  %x = call i32 @f3()
  br label %exit
exit:
  ret i32 %x
}

define i32 @f5(i32 %i) {
  %cond = icmp sle i32 %i, 1
  br i1 %cond, label %cond_true, label %cond_false, !prof !4
cond_true:
  %ret = call i32 @f3()
  ret i32 %ret
cond_false:
  ret i32 0
}

!1 = !{!"branch_weights", i32 1, i32 3}
!2 = !{!"branch_weights", i32 2, i32 1}
!3 = !{!"branch_weights", i32 5, i32 1}
!4 = !{!"branch_weights", i32 2, i32 3}

; the labels' first index matches the function, and the second index the block.
; for example, .LBB0_1 is the second block in f0 ("yes")
; EXPR: .ascii "f0"
; EXPR: .uleb128    (((((.LBB_END0_1-.LBB0_1)*25)+(((.LBB_END0_2-.LBB0_2)*74)+((.LBB_END0_0-.LBB0_0)*100)))*100)+((((.LBB_END1_2-.LBB1_2)*65)+((.LBB_END1_0-.LBB1_0)*100))*38))+((((.LBB_END2_1-.LBB2_1)*16)+(((.LBB_END2_2-.LBB2_2)*83)+((.LBB_END2_0-.LBB2_0)*100)))*91)
; EXPR: .ascii "f2"
; EXPR: .uleb128   ((((.LBB_END1_2-.LBB1_2)*65)+((.LBB_END1_0-.LBB1_0)*100))*16)+((((.LBB_END2_1-.LBB2_1)*16)+(((.LBB_END2_2-.LBB2_2)*83)+((.LBB_END2_0-.LBB2_0)*100)))*100)
; EXPR: .ascii "f3"
; EXPR: .uleb128 ((.LBB_END3_0-.LBB3_0)*100)*100
; EXPR: .ascii "f4"
; EXPR: .uleb128 (((.LBB_END3_0-.LBB3_0)*100)*100)+(((.LBB_END4_0-.LBB4_0)*100)*100)
; EXPR: .ascii "f5"
; EXPR: .uleb128 (((.LBB_END3_0-.LBB3_0)*100)*40)+((((.LBB_END5_1-.LBB5_1)*40)+(((.LBB_END5_2-.LBB5_2)*60)+((.LBB_END5_0-.LBB5_0)*100)))*100)

; Note: because we multiply by 100 both when computing internal IWS and call
; graph IWS, the values below should be seen as inflated by 10000
; OBJ: f0,386914,23
; OBJ: f2,212560,13
; OBJ: f3,60000,2
; OBJ: f4,140000,8
; OBJ: f5,124000,6

; For reference, we expect the output to look like this - which should allow
; tracking the blocks and their size, to cross-check the OBJ labels.
; DUMP: <f0>:
; DUMP-NEXT:         0:
; DUMP:              6: {{.*}} jle
; DUMP-NEXT:         8:
; DUMP:              e: {{.*}} retq
; DUMP-NEXT:         f:
; DUMP:             15: {{.*}} retq
; DUMP-NEXT:        16:

; DUMP: <f1>:
; DUMP-NEXT:        20:
; DUMP:             2b: {{.*}} jg
; DUMP-NEXT:        2d:
; DUMP:             35: {{.*}} retq
; DUMP-NEXT:        36:
; DUMP:             39: {{.*}} retq
; DUMP-NEXT:        3a:

; DUMP: <f2>:
; DUMP-NEXT:        40:
; DUMP:             4b: {{.*}} jge
; DUMP-NEXT:        4d:
; DUMP:             50: {{.*}} retq
; DUMP-NEXT:        51:
; DUMP:             5c:{{.*}} retq
; DUMP-NEXT:        5d:

; DUMP: <f3>:
; DUMP-NEXT:        60:
; DUMP-NEXT:        65: {{.*}} retq
; DUMP-NEXT:        66:

; DUMP: <f4>:
; DUMP-NEXT:        70:
; DUMP-NEXT:        71: {{.*}} callq
; DUMP-NEXT:        76: {{.*}} popq
; DUMP-NEXT:        77: {{.*}} retq
; DUMP-NEXT:        78:

; DUMP: <f5>:
; DUMP-NEXT:        80:
; DUMP:             83: {{.*}} jle
; DUMP-NEXT:        85:
; DUMP:             87: {{.*}} retq
; DUMP-NEXT:        88:
; DUMP:             8f: {{.*}} retq
