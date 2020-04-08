//===- MachineStripDebug.cpp - Strip debug info ---------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file This removes debug info from everything. It can be used to ensure
/// tests can be debugified without affecting the output MIR.
//===----------------------------------------------------------------------===//

#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineModuleInfo.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/IR/DebugInfo.h"
#include "llvm/InitializePasses.h"

#define DEBUG_TYPE "mir-strip-debug"

using namespace llvm;

namespace {

struct StripDebugMachineModule : public ModulePass {
  bool runOnModule(Module &M) override {
    MachineModuleInfo &MMI =
        getAnalysis<MachineModuleInfoWrapperPass>().getMMI();

    bool Changed = false;
    for (Function &F : M.functions()) {
      MachineFunction &MF = MMI.getOrCreateMachineFunction(F);
      for (MachineBasicBlock &MBB : MF) {
        for (MachineBasicBlock::iterator I = MBB.begin(), E = MBB.end();
             I != E;) {
          if (I->isDebugInstr()) {
            // FIXME: We should remove all of them. However, AArch64 emits an
            //        invalid `DBG_VALUE $lr` with only one operand instead of
            //        the usual three and has a test that depends on it's
            //        preservation. Preserve it for now.
            if (I->getNumOperands() > 1) {
              LLVM_DEBUG(dbgs() << "Removing debug instruction " << *I);
              I = MBB.erase(I);
              Changed |= true;
              continue;
            }
          }
          if (I->getDebugLoc()) {
            LLVM_DEBUG(dbgs() << "Removing location " << *I);
            I->setDebugLoc(DebugLoc());
            Changed |= true;
            ++I;
            continue;
          }
          LLVM_DEBUG(dbgs() << "Keeping " << *I);
          ++I;
        }
      }
    }

    Changed |= StripDebugInfo(M);

    NamedMDNode *NMD = M.getNamedMetadata("llvm.debugify");
    if (NMD) {
      NMD->eraseFromParent();
      Changed |= true;
    }

    NMD = M.getModuleFlagsMetadata();
    if (NMD) {
      // There must be an easier way to remove an operand from a NamedMDNode.
      SmallVector<MDNode *, 4> Flags;
      for (MDNode *Flag : NMD->operands())
        Flags.push_back(Flag);
      NMD->clearOperands();
      for (MDNode *Flag : Flags) {
        MDString *Key = dyn_cast_or_null<MDString>(Flag->getOperand(1));
        if (Key->getString() == "Debug Info Version") {
          Changed |= true;
          continue;
        }
        NMD->addOperand(Flag);
      }
      // If we left it empty we might as well remove it.
      if (NMD->getNumOperands() == 0)
        NMD->eraseFromParent();
    }

    return Changed;
  }

  StripDebugMachineModule() : ModulePass(ID) {}

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<MachineModuleInfoWrapperPass>();
    AU.addPreserved<MachineModuleInfoWrapperPass>();
  }

  static char ID; // Pass identification.
};
char StripDebugMachineModule::ID = 0;

} // end anonymous namespace

INITIALIZE_PASS_BEGIN(StripDebugMachineModule, DEBUG_TYPE,
                      "Machine Strip Debug Module", false, false)
INITIALIZE_PASS_END(StripDebugMachineModule, DEBUG_TYPE,
                    "Machine Strip Debug Module", false, false)

ModulePass *createStripDebugMachineModulePass() {
  return new StripDebugMachineModule();
}
