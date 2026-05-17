# Changelog

## 1.0.0 (2026-05-16)


### Features

* add --skip_stages option to build-toolchain.sh ([#104](https://github.com/grahame-org/gnu-tools-for-stm32/issues/104)) ([f633ebf](https://github.com/grahame-org/gnu-tools-for-stm32/commit/f633ebfee1cea6dd9587970449e1b32f3d19d6d9))
* add cached build-toolchain step to workflow ([#29](https://github.com/grahame-org/gnu-tools-for-stm32/issues/29)) ([2c2db89](https://github.com/grahame-org/gnu-tools-for-stm32/commit/2c2db89d160229b7d41e7dfc71fca3fef748558b))
* add docker-action/entrypoint.sh and update Dockerfile with ENTRYPOINT ([#758](https://github.com/grahame-org/gnu-tools-for-stm32/issues/758)) ([725e0ad](https://github.com/grahame-org/gnu-tools-for-stm32/commit/725e0ad2540939952e2b161ab52201bbb23ff645))
* add gcc-first stage cache restore/build/save triple with dedicated build script ([#161](https://github.com/grahame-org/gnu-tools-for-stm32/issues/161)) ([94a4d90](https://github.com/grahame-org/gnu-tools-for-stm32/commit/94a4d906a27428b18bee5f1b9bdf33f3a85a0b99))
* add GitHub Issue templates with commitlint guidance ([#28](https://github.com/grahame-org/gnu-tools-for-stm32/issues/28)) ([6041ca4](https://github.com/grahame-org/gnu-tools-for-stm32/commit/6041ca44d9a178a465ea909f3308f4c713cbd21d))
* add merge-gcc-final.sh to combine rmprofile and aprofile install trees ([#662](https://github.com/grahame-org/gnu-tools-for-stm32/issues/662)) ([de1907c](https://github.com/grahame-org/gnu-tools-for-stm32/commit/de1907caf8f1aaa0c323d212539122d742970945))
* add single-profile MULTILIB_LIST comment and aprofile test ([#637](https://github.com/grahame-org/gnu-tools-for-stm32/issues/637)) ([09975c1](https://github.com/grahame-org/gnu-tools-for-stm32/commit/09975c1ba81d0277a15537f07a804539e312e5cf))
* create Dockerfile and .dockerignore for STM32 toolchain container ([#725](https://github.com/grahame-org/gnu-tools-for-stm32/issues/725)) ([37f367b](https://github.com/grahame-org/gnu-tools-for-stm32/commit/37f367b84fbc035207be9f712054f01aa0cdea98))
* extract build-binutils.sh from build-toolchain.sh for independent caching ([#169](https://github.com/grahame-org/gnu-tools-for-stm32/issues/169)) ([e65741c](https://github.com/grahame-org/gnu-tools-for-stm32/commit/e65741caec405ef821fb9743b4ab0f27f1febfda))
* initialise gh-aw agents ([#180](https://github.com/grahame-org/gnu-tools-for-stm32/issues/180)) ([80c8cac](https://github.com/grahame-org/gnu-tools-for-stm32/commit/80c8cacfed9266c7d10382e59589d71552d4bc44))
* report compressed cache size in job summaries ([#657](https://github.com/grahame-org/gnu-tools-for-stm32/issues/657)) ([0fb62e4](https://github.com/grahame-org/gnu-tools-for-stm32/commit/0fb62e4c6bd79648cbf9163ee4db160d2c6ce278))


### Bug Fixes

* add explanatory comments to per-line SC1083 suppressions in build-common.sh ([#209](https://github.com/grahame-org/gnu-tools-for-stm32/issues/209)) ([87b3892](https://github.com/grahame-org/gnu-tools-for-stm32/commit/87b3892d9d6d816616a8fa353bc297aa80cecf66))
* add protected-files fallback-to-issue to daily-test-improver workflow ([#617](https://github.com/grahame-org/gnu-tools-for-stm32/issues/617)) ([d5d9f4e](https://github.com/grahame-org/gnu-tools-for-stm32/commit/d5d9f4efd93cadf43aaa27f5d906f8f46976c5a7))
* add shellcheck shell=bash directive to build-common.sh (SC2148) ([#171](https://github.com/grahame-org/gnu-tools-for-stm32/issues/171)) ([580cd19](https://github.com/grahame-org/gnu-tools-for-stm32/commit/580cd194b78419b3d3a34556525dcd8fb8a896d4))
* add targeted per-line SC2034 suppressions in parse_toolchain_args() ([#551](https://github.com/grahame-org/gnu-tools-for-stm32/issues/551)) ([7f09488](https://github.com/grahame-org/gnu-tools-for-stm32/commit/7f0948899fc87834e3b2cce74b1b56c91e873763))
* add targeted SC2034 suppressions for version and URL constants in build-common.sh ([#553](https://github.com/grahame-org/gnu-tools-for-stm32/issues/553)) ([c420f63](https://github.com/grahame-org/gnu-tools-for-stm32/commit/c420f63a0445a0b41005f0e35c96565021ae2cc0))
* address actionlint findings ([#233](https://github.com/grahame-org/gnu-tools-for-stm32/issues/233)) ([4d5d159](https://github.com/grahame-org/gnu-tools-for-stm32/commit/4d5d15901563a045a872a0bda8ae7a95334bb6b3))
* address SC2046 and SC2086 in build-newlib-nano.sh; add to shellcheck CI ([#615](https://github.com/grahame-org/gnu-tools-for-stm32/issues/615)) ([d525102](https://github.com/grahame-org/gnu-tools-for-stm32/commit/d5251020d79920f7cb77dfd738c05f096067d7eb))
* **ci:** document large-repo workaround for audit workflow spawnSync ENOBUFS failure ([#56](https://github.com/grahame-org/gnu-tools-for-stm32/issues/56)) ([cf52744](https://github.com/grahame-org/gnu-tools-for-stm32/commit/cf52744b191b82771df44b1d3da4eb4dd9975a54))
* **ci:** resolve hashFiles timeout causing perpetual toolchain cache misses ([#70](https://github.com/grahame-org/gnu-tools-for-stm32/issues/70)) ([484e57b](https://github.com/grahame-org/gnu-tools-for-stm32/commit/484e57bb1308546c0fa2226a252f253edb78f249))
* cross-platform .exe suffix handling in arm-none-eabi-gcc.cmake ([#81](https://github.com/grahame-org/gnu-tools-for-stm32/issues/81)) ([cf5d836](https://github.com/grahame-org/gnu-tools-for-stm32/commit/cf5d8363424afec7a1d4734dda3c267dcec18e0a))
* disable lockdown mode in issue-monster workflow ([#486](https://github.com/grahame-org/gnu-tools-for-stm32/issues/486)) ([38c241f](https://github.com/grahame-org/gnu-tools-for-stm32/commit/38c241f9501af64d2ddaa34abe5865620a4d1267))
* export top-level path and component constants in build-common.sh to resolve SC2034 ([#547](https://github.com/grahame-org/gnu-tools-for-stm32/issues/547)) ([b5220dd](https://github.com/grahame-org/gnu-tools-for-stm32/commit/b5220dd79c6fde2b696140d1480cd0a67116430b))
* fix SC2046+SC2086 shellcheck findings in build-newlib.sh ([#613](https://github.com/grahame-org/gnu-tools-for-stm32/issues/613)) ([9be4389](https://github.com/grahame-org/gnu-tools-for-stm32/commit/9be43899ecfcb44248c1e66cd4090a8cd94b955f))
* fix SC2086 (unquoted variables) in build-prerequisites.sh MinGW section ([#626](https://github.com/grahame-org/gnu-tools-for-stm32/issues/626)) ([aa2beab](https://github.com/grahame-org/gnu-tools-for-stm32/commit/aa2beab7344ea5169ce0cee1b757f37929d13ba5))
* fix SC2086 unquoted variable findings in build-binutils.sh ([#611](https://github.com/grahame-org/gnu-tools-for-stm32/issues/611)) ([f19b1f5](https://github.com/grahame-org/gnu-tools-for-stm32/commit/f19b1f5c2c77b9aa7bdcf9e0d8cb0033e45dc169))
* increase daily-test-improver repo-memory max-file-size to 10 MiB ([#188](https://github.com/grahame-org/gnu-tools-for-stm32/issues/188)) ([d1518a4](https://github.com/grahame-org/gnu-tools-for-stm32/commit/d1518a4e661ad3d761a737c139846dc26fc57962))
* prevent ci-coach PR creation for workflow file changes ([#269](https://github.com/grahame-org/gnu-tools-for-stm32/issues/269)) ([75a113e](https://github.com/grahame-org/gnu-tools-for-stm32/commit/75a113ef3330e7e24d7628915d436e52dc70d31f))
* quote [III-2] in echo call in build-newlib.sh to prevent glob interpretation ([#696](https://github.com/grahame-org/gnu-tools-for-stm32/issues/696)) ([27f4b7e](https://github.com/grahame-org/gnu-tools-for-stm32/commit/27f4b7ec706711a2c279ad6dd595b9bb1b288ba5))
* quote $(dirname "$0") and source path in remaining build scripts (SC2046) ([#563](https://github.com/grahame-org/gnu-tools-for-stm32/issues/563)) ([8c0c851](https://github.com/grahame-org/gnu-tools-for-stm32/commit/8c0c85147896fee298c0ba94f9791b832947c668))
* quote $(dirname "$0") in build-gcc-final.sh to fix SC2046 ([#560](https://github.com/grahame-org/gnu-tools-for-stm32/issues/560)) ([ad5050f](https://github.com/grahame-org/gnu-tools-for-stm32/commit/ad5050f62edbcd915268027d5699c2b10303e044))
* quote $(dirname "$0") in build-gdb.sh to fix SC2046 ([#552](https://github.com/grahame-org/gnu-tools-for-stm32/issues/552)) ([a9fe496](https://github.com/grahame-org/gnu-tools-for-stm32/commit/a9fe496829526c0f2026d4e97bb8582917ffffbe))
* quote $(dirname $0) in build-gcc-size-libstdcxx.sh (SC2046) ([#558](https://github.com/grahame-org/gnu-tools-for-stm32/issues/558)) ([51ef5f6](https://github.com/grahame-org/gnu-tools-for-stm32/commit/51ef5f6c78ae050fe77fe5b54d8b4b6cd981196f))
* quote $(dirname $0) in build-newlib-nano.sh to fix SC2046 ([#555](https://github.com/grahame-org/gnu-tools-for-stm32/issues/555)) ([c4900a5](https://github.com/grahame-org/gnu-tools-for-stm32/commit/c4900a51a906c5d4aa30a5ccfcbd99dc1c8ec932))
* quote echo Task bracket expressions to resolve SC2102 ([#184](https://github.com/grahame-org/gnu-tools-for-stm32/issues/184)) ([3564452](https://github.com/grahame-org/gnu-tools-for-stm32/commit/356445287e9ee3ffa658524d1e4eb8e80a5d4ca3))
* quote HOST_MINGW_TOOL and path variables in build-prerequisites.sh (SC2086) ([#598](https://github.com/grahame-org/gnu-tools-for-stm32/issues/598)) ([69308ed](https://github.com/grahame-org/gnu-tools-for-stm32/commit/69308ed344e49d3d50838bff9c61db9f8972c13f))
* quote positional params in pack_dir_clean, use conditional expansion for variadic args ([#559](https://github.com/grahame-org/gnu-tools-for-stm32/issues/559)) ([c3069a3](https://github.com/grahame-org/gnu-tools-for-stm32/commit/c3069a39af765ca6f910dfe453de9faed5b4f920))
* quote SC2086 variables in build-prerequisites.sh I-0/I-1 tasks ([#586](https://github.com/grahame-org/gnu-tools-for-stm32/issues/586)) ([09d370e](https://github.com/grahame-org/gnu-tools-for-stm32/commit/09d370e97796c0acf994f8d3fc52a0a061868b6a))
* quote SC2086 variables in MinGW mpfr (II-3) and mpc (II-4) tasks ([#602](https://github.com/grahame-org/gnu-tools-for-stm32/issues/602)) ([0ca6eca](https://github.com/grahame-org/gnu-tools-for-stm32/commit/0ca6eca4dcb9f8a0ed50d0c20c72b45905321a77))
* quote script path references in build-newlib.sh to fix SC2046 ([#495](https://github.com/grahame-org/gnu-tools-for-stm32/issues/495)) ([6f15332](https://github.com/grahame-org/gnu-tools-for-stm32/commit/6f15332388c9772de5e397f77eeff4c203f88a5f))
* quote unquoted variables (SC2086) in build-prerequisites.sh lines 191-352 ([#625](https://github.com/grahame-org/gnu-tools-for-stm32/issues/625)) ([7a6cfb2](https://github.com/grahame-org/gnu-tools-for-stm32/commit/7a6cfb2acb4b8746479d83fec51be77a0aa1b62d))
* quote unquoted variables (SC2086) in build-toolchain.sh lines 41–218 ([#665](https://github.com/grahame-org/gnu-tools-for-stm32/issues/665)) ([1a51d6f](https://github.com/grahame-org/gnu-tools-for-stm32/commit/1a51d6f93154316d042125bde8d17d9f2282f6b6))
* quote unquoted variables in build-prerequisites.sh mpfr and mpc tasks ([#588](https://github.com/grahame-org/gnu-tools-for-stm32/issues/588)) ([4916805](https://github.com/grahame-org/gnu-tools-for-stm32/commit/4916805c1e9d340dc615c86366399efbe92e2df0))
* quote unquoted variables in isl and expat tasks in build-prerequisites.sh ([#595](https://github.com/grahame-org/gnu-tools-for-stm32/issues/595)) ([27d380e](https://github.com/grahame-org/gnu-tools-for-stm32/commit/27d380e751b6bfc79ebef60811ac7d4a2044a0d6))
* quote variables and suppress SC2086 in build-toolchain.sh lines 454–528 ([#671](https://github.com/grahame-org/gnu-tools-for-stm32/issues/671)) ([8c55047](https://github.com/grahame-org/gnu-tools-for-stm32/commit/8c55047c32c0610a7948ff69bfc65836f220e29a))
* quote variables in build-gcc-first.sh to resolve SC2086 findings ([#612](https://github.com/grahame-org/gnu-tools-for-stm32/issues/612)) ([b1bb6f0](https://github.com/grahame-org/gnu-tools-for-stm32/commit/b1bb6f0de7d505a269e9ccf89099070952d64e20))
* quote variables in MinGW isl and expat sections (SC2086) ([#627](https://github.com/grahame-org/gnu-tools-for-stm32/issues/627)) ([1351655](https://github.com/grahame-org/gnu-tools-for-stm32/commit/135165529e3b5a20cf5e71f2bbef979211ebe221))
* quote variables to fix SC2086 in build-prerequisites.sh lines 41-78 ([#546](https://github.com/grahame-org/gnu-tools-for-stm32/issues/546)) ([c47988b](https://github.com/grahame-org/gnu-tools-for-stm32/commit/c47988b1ca3f690b2de5fdbe212eeb6386bf538a))
* remove global SC2034 suppression from .shellcheckrc ([#686](https://github.com/grahame-org/gnu-tools-for-stm32/issues/686)) ([469ca09](https://github.com/grahame-org/gnu-tools-for-stm32/commit/469ca092fe535d88d90328ca718d32f812073cd2))
* remove legacy x-prefix comparisons from build scripts (SC2268) ([#167](https://github.com/grahame-org/gnu-tools-for-stm32/issues/167)) ([a4d1f9f](https://github.com/grahame-org/gnu-tools-for-stm32/commit/a4d1f9f697f1c8c5d144f36aeedf74d4406195b1))
* remove unnecessary backslash before `-` in expr call in build-common.sh ([#693](https://github.com/grahame-org/gnu-tools-for-stm32/issues/693)) ([73c8648](https://github.com/grahame-org/gnu-tools-for-stm32/commit/73c864803f00ce746c15d48d1ab2381a74c79d44))
* remove unreachable return 1 after error() call in build-common.sh (SC2317) ([#695](https://github.com/grahame-org/gnu-tools-for-stm32/issues/695)) ([b5eed44](https://github.com/grahame-org/gnu-tools-for-stm32/commit/b5eed442b84adf2711fcb93fb71570070416557c))
* remove unused config-option variables from build-toolchain.sh (SC2034) ([#554](https://github.com/grahame-org/gnu-tools-for-stm32/issues/554)) ([1bb7ffd](https://github.com/grahame-org/gnu-tools-for-stm32/commit/1bb7ffdf7500be4d4a15dff192b106b6d43542d8))
* replace $@ with $* in error/warning functions to fix SC2145 ([#123](https://github.com/grahame-org/gnu-tools-for-stm32/issues/123)) ([35cb85d](https://github.com/grahame-org/gnu-tools-for-stm32/commit/35cb85d06bd5ef75561fda284fe32938efcbfaec))
* replace backtick command substitutions with $() in build scripts (SC2006) ([#154](https://github.com/grahame-org/gnu-tools-for-stm32/issues/154)) ([edb1568](https://github.com/grahame-org/gnu-tools-for-stm32/commit/edb1568afb945942773e7870aa4d7d377880a1ac))
* resolve all 48 SC2086 (unquoted variable) findings in build-common.sh ([#568](https://github.com/grahame-org/gnu-tools-for-stm32/issues/568)) ([05b52a7](https://github.com/grahame-org/gnu-tools-for-stm32/commit/05b52a70971ee92cc46adb17c7a5aff87a823e5d))
* resolve all SC2086 (unquoted variables) in build-toolchain.sh ([#672](https://github.com/grahame-org/gnu-tools-for-stm32/issues/672)) ([5352d03](https://github.com/grahame-org/gnu-tools-for-stm32/commit/5352d03c66fe37502be96ae11dd83b74f6bc1b17))
* resolve SC2034 for config and packaging vars in build-common.sh ([#557](https://github.com/grahame-org/gnu-tools-for-stm32/issues/557)) ([2e96667](https://github.com/grahame-org/gnu-tools-for-stm32/commit/2e966672258645655427976bc81973562af54407))
* resolve SC2046, SC2086, SC2016, and SC2102 findings in build-gdb.sh ([#666](https://github.com/grahame-org/gnu-tools-for-stm32/issues/666)) ([a74fdbc](https://github.com/grahame-org/gnu-tools-for-stm32/commit/a74fdbced66dd4232f29492853acb4c5a48c0623))
* resolve SC2086 shellcheck findings in build-gcc-size-libstdcxx.sh ([#664](https://github.com/grahame-org/gnu-tools-for-stm32/issues/664)) ([a6508be](https://github.com/grahame-org/gnu-tools-for-stm32/commit/a6508be6fd00f64f309c839464d853b9882e5a04))
* resolve SC2154 shellcheck warnings in build-toolchain.sh ([#501](https://github.com/grahame-org/gnu-tools-for-stm32/issues/501)) ([c36ee14](https://github.com/grahame-org/gnu-tools-for-stm32/commit/c36ee146e18ab4e911e5c151183c107d4e0444fd))
* set code simplifier PR base branch from workflow ref ([#268](https://github.com/grahame-org/gnu-tools-for-stm32/issues/268)) ([7677591](https://github.com/grahame-org/gnu-tools-for-stm32/commit/7677591d907bfaf0db92850fd8e8418ef07724e0))
* suppress SC2034 warnings for tool-detection variables in build-common.sh ([#562](https://github.com/grahame-org/gnu-tools-for-stm32/issues/562)) ([e64a959](https://github.com/grahame-org/gnu-tools-for-stm32/commit/e64a959c087c0eecae95b213f70dd89e6d0ea4d5))
* suppress SC2086 and SC2162 in build-toolchain.sh lines 220–287 ([#667](https://github.com/grahame-org/gnu-tools-for-stm32/issues/667)) ([4f955f3](https://github.com/grahame-org/gnu-tools-for-stm32/commit/4f955f396390d9972ec9004985516273b1dbab6d))
* suppress SC2086 in build-toolchain.sh lines 288–344 ([#668](https://github.com/grahame-org/gnu-tools-for-stm32/issues/668)) ([81df35b](https://github.com/grahame-org/gnu-tools-for-stm32/commit/81df35b8707cdcecd62086ffeb3de5aaad01a93c))
* suppress SC2086 in build-toolchain.sh lines 345–388 (MinGW IV-0/IV-1) ([#669](https://github.com/grahame-org/gnu-tools-for-stm32/issues/669)) ([ae6fef8](https://github.com/grahame-org/gnu-tools-for-stm32/commit/ae6fef85f42fc2fcb217a8e3785d574baaa021ed))
* suppress SC2086 in build-toolchain.sh lines 389–453 (MinGW IV-2/IV-3 GCC-final) ([#670](https://github.com/grahame-org/gnu-tools-for-stm32/issues/670)) ([ff333af](https://github.com/grahame-org/gnu-tools-for-stm32/commit/ff333affaa56f22d66284370461e27c03369aefd))
* suppress SC2086/SC2046 in build-gcc-final.sh and add to shellcheck CI ([#663](https://github.com/grahame-org/gnu-tools-for-stm32/issues/663)) ([cc39dda](https://github.com/grahame-org/gnu-tools-for-stm32/commit/cc39dda1ad7f16095a1a8d307f892526dbe28de7))
* update shellcheck source directives to use repo-root-relative path ([#694](https://github.com/grahame-org/gnu-tools-for-stm32/issues/694)) ([e43c529](https://github.com/grahame-org/gnu-tools-for-stm32/commit/e43c52951bdcf2e8c938d4b3d735fddff4741302))


### Performance Improvements

* add timing markers to build-gcc-size-libstdcxx ([#532](https://github.com/grahame-org/gnu-tools-for-stm32/issues/532)) ([1094c36](https://github.com/grahame-org/gnu-tools-for-stm32/commit/1094c36da1a5b7b4f9caa18582f14779c8bf030b))
* optimize gcc-size-libstdcxx build time by restricting to rmprofile multilib ([#499](https://github.com/grahame-org/gnu-tools-for-stm32/issues/499)) ([16d9790](https://github.com/grahame-org/gnu-tools-for-stm32/commit/16d9790b20c4badb312dee5efb93b15bf585092f))


### Reverts

* disable lockdown mode in issue-monster workflow ([#487](https://github.com/grahame-org/gnu-tools-for-stm32/issues/487)) ([3af2101](https://github.com/grahame-org/gnu-tools-for-stm32/commit/3af21019c378677511be759ca45a4051c1765749))

## Changelog
