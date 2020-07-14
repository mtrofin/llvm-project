import lldb
import binascii
import os
from lldbsuite.test.lldbtest import *
from lldbsuite.test.decorators import *
from gdbclientutils import *


class TestProcessConnect(GDBRemoteTestBase):

    NO_DEBUG_INFO_TESTCASE = True

    @expectedFailureAll(hostoslist=["windows"], triple='.*-android')
    def test_gdb_remote_sync(self):
        """Test the gdb-remote command in synchronous mode"""
        try:
            self.dbg.SetAsync(False)
            self.expect("gdb-remote %d" % self.server.port,
                        substrs=['Process', 'stopped'])
        finally:
            self.dbg.GetSelectedPlatform().DisconnectRemote()

    @expectedFailureAll(hostoslist=["windows"], triple='.*-android')
    def test_gdb_remote_async(self):
        """Test the gdb-remote command in asynchronous mode"""
        try:
            self.dbg.SetAsync(True)
            self.expect("gdb-remote %d" % self.server.port,
                        matching=False,
                        substrs=['Process', 'stopped'])
            lldbutil.expect_state_changes(self, self.dbg.GetListener(),
                                          self.process(), [lldb.eStateStopped])
        finally:
            self.dbg.GetSelectedPlatform().DisconnectRemote()

    @expectedFailureAll(hostoslist=["windows"], triple='.*-android')
    def test_process_connect_sync(self):
        """Test the gdb-remote command in synchronous mode"""
        try:
            self.dbg.SetAsync(False)
            self.expect("process connect connect://localhost:%d" %
                        self.server.port,
                        substrs=['Process', 'stopped'])
        finally:
            self.dbg.GetSelectedPlatform().DisconnectRemote()

    @expectedFailureAll(hostoslist=["windows"], triple='.*-android')
    def test_process_connect_async(self):
        """Test the gdb-remote command in asynchronous mode"""
        try:
            self.dbg.SetAsync(True)
            self.expect("process connect connect://localhost:%d" %
                        self.server.port,
                        matching=False,
                        substrs=['Process', 'stopped'])
            lldbutil.expect_state_changes(self, self.dbg.GetListener(),
                                          self.process(), [lldb.eStateStopped])
        finally:
            self.dbg.GetSelectedPlatform().DisconnectRemote()
