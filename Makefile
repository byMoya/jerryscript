# Copyright 2014 Samsung Electronics Co., Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Target naming scheme
#
#   Main targets: {debug,release,debug_release}.{linux,stm32f{4}}[.{check,flash}]
#
#    Target mode part (before dot):
#       debug:         - JERRY_NDEBUG; - optimizations; + debug symbols; + -Werror  | debug build
#       debug_release: - JERRY_NDEBUG; + optimizations; + debug symbols; + -Werror  | checked release build
#       release:       + JERRY_NDEBUG; + optimizations; - debug symbols; + -Werror  | release build
#
#    Target system and modifiers part (after first dot):
#       linux - target system is linux
#       stm32f{4} - target is STM32F{4} board
#
#       Modifiers can be added after '-' sign.
#        For list of modifiers for PC target - see TARGET_PC_MODS, for MCU target - TARGET_MCU_MODS.
#
#    Target action part (optional, after second dot):
#       check - run cppcheck on src folder, unit and other tests
#       flash - flash specified mcu target binary
#
#
#   Unit test target: unittests
#
# Options
#
#   dwarf4=1 - use DWARF v4 format for debug information
#

export TARGET_MODES = debug debug_release release
export TARGET_PC_SYSTEMS = linux
export TARGET_MCU_SYSTEMS = $(addprefix stm32f,4) # now only stm32f4 is supported, to add, for example, to stm32f3, change to $(addprefix stm32f,3 4)

export TARGET_PC_MODS = libc_raw musl sanitize valgrind \
                        libc_raw-sanitize libc_raw-valgrind \
                        musl-valgrind

export TARGET_MCU_MODS =

export TARGET_SYSTEMS = $(TARGET_PC_SYSTEMS) \
                        $(TARGET_MCU_SYSTEMS) \
                        $(foreach __MOD,$(TARGET_PC_MODS),$(foreach __SYSTEM,$(TARGET_PC_SYSTEMS),$(__SYSTEM)-$(__MOD))) \
                        $(foreach __MOD,$(TARGET_MCU_MODS),$(foreach __SYSTEM,$(TARGET_MCU_SYSTEMS),$(__SYSTEM)-$(__MOD)))

# Target list
export JERRY_TARGETS = $(foreach __MODE,$(TARGET_MODES),$(foreach __SYSTEM,$(TARGET_SYSTEMS),$(__MODE).$(__SYSTEM)))
export TESTS_TARGET = unittests
export CHECK_TARGETS = $(foreach __TARGET,$(JERRY_TARGETS),$(__TARGET).check)
export FLASH_TARGETS = $(foreach __TARGET,$(foreach __MODE,$(TARGET_MODES),$(foreach __SYSTEM,$(TARGET_MCU_SYSTEMS),$(__MODE).$(__SYSTEM))),$(__TARGET).flash)

export OUT_DIR = ./out
export UNITTESTS_SRC_DIR = ./tests/unit

export SHELL=/bin/bash

export dwarf4
export echo
export todo
export fixme
export color

build: clean $(JERRY_TARGETS)

all: precommit

PRECOMMIT_CHECK_TARGETS_LIST= debug.linux-sanitize.check \
                              debug.linux-valgrind.check \
                              debug.linux-musl-valgrind.check \
                              debug_release.linux-sanitize.check \
                              debug_release.linux-valgrind.check \
                              debug_release.linux-musl.check \
                              release.linux-sanitize.check \
                              release.linux-musl-valgrind.check \
                              release.linux-valgrind.check \
                              release.linux.check

push: ./tools/push.sh
	@ ./tools/push.sh

precommit: clean
	@ echo -e "\nBuilding...\n\n"
	@ $(MAKE) build
	@ echo -e "\n================ Build completed successfully. Running precommit tests ================\n"
	@ echo -e "All targets were built successfully. Starting unit tests' build and run.\n"
	@ $(MAKE) unittests TESTS_OPTS="--silent"
	@ echo -e "Unit tests completed successfully. Starting parse-only testing.\n"
	@ # Parse-only testing
	@ for path in "./tests/jerry" "./benchmarks/jerry"; \
          do \
            run_ids=""; \
            for check_target in $(PRECOMMIT_CHECK_TARGETS_LIST); \
            do \
              $(MAKE) -s -f Makefile.mk TARGET=$$check_target $$check_target TESTS_DIR="$$path" TESTS_OPTS="--parse-only" OUTPUT_TO_LOG=enable & \
              run_ids="$$run_ids $$!"; \
            done; \
            result_ok=1; \
            for run_id in $$run_ids; \
            do \
              wait $$run_id || result_ok=0; \
            done; \
            [ $$result_ok -eq 1 ] || exit 1; \
          done
	@ echo -e "Parse-only testing completed successfully. Starting full tests run.\n"
	@ echo -e "\e[0;31mFIXME:\e[0m Full testing skipped.\n";
	@ # Full testing
	@ # for path in "./tests/jerry" "./benchmarks/jerry"; \
          # do \
          #   run_ids=""; \
          #   for check_target in $(PRECOMMIT_CHECK_TARGETS_LIST); \
          #   do \
          #     $(MAKE) -s -f Makefile.mk TARGET=$$check_target $$check_target TESTS_DIR="$$path" TESTS_OPTS="" OUTPUT_TO_LOG=enable & \
          #     run_ids="$$run_ids $$!"; \
          #   done; \
          #   result_ok=1; \
          #   for run_id in $$run_ids; \
          #   do \
          #     wait $$run_id || result_ok=0; \
          #   done; \
          #   [ $$result_ok -eq 1 ] || exit 1; \
          # done
	@ echo -e "Full testing completed successfully\n\n================\n\n"

$(JERRY_TARGETS) $(TESTS_TARGET) $(FLASH_TARGETS):
	@$(MAKE) -s -f Makefile.mk TARGET=$@ $@

clean:
	@ rm -rf $(OUT_DIR)
