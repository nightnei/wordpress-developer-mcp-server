# Changelog

## [2.0.0](https://github.com/nightnei/wordpress-developer-mcp-server/compare/v1.0.0...v2.0.0) (2026-03-03)


### ⚠ BREAKING CHANGES

* zero-setup installation with install.sh

### Features

* add env ([66f706b](https://github.com/nightnei/wordpress-developer-mcp-server/commit/66f706b6b15371b86c8334146b3012d03104e3f0))
* force using provided tools for fs modifications ([922a97c](https://github.com/nightnei/wordpress-developer-mcp-server/commit/922a97cfdf6dc57f10b90221eb48eb7659a69649))
* improve info to login to wpcom ([dfd41a3](https://github.com/nightnei/wordpress-developer-mcp-server/commit/dfd41a3a4a20f5a3e2c34b9ebead23f3c6923666))
* info to login to wpcom ([bdb24e0](https://github.com/nightnei/wordpress-developer-mcp-server/commit/bdb24e0a91506c1bb4310cf6bd540c011d405fc1))
* **instructions:** add info about image generation ([e8a9042](https://github.com/nightnei/wordpress-developer-mcp-server/commit/e8a9042054217668e1f53ac339db772d0a41e343))
* **instructions:** add info about Studio app ([bef5a2d](https://github.com/nightnei/wordpress-developer-mcp-server/commit/bef5a2d2e793add0cc7bee7f5303d11febccefb7))
* **instructions:** add info about using this mcp ([2a37b4d](https://github.com/nightnei/wordpress-developer-mcp-server/commit/2a37b4d969ceb0937d857fc4b2276c72279ffee9))
* **tools:** add capability to remove folders ([ed35c77](https://github.com/nightnei/wordpress-developer-mcp-server/commit/ed35c77e5b5ea55a17ea57a0db3f53f87f2257d9))
* **tools:** add custom domain and https for site set command ([bba9bf9](https://github.com/nightnei/wordpress-developer-mcp-server/commit/bba9bf9b97cff8eba74a0f5bb56424e810a38467))
* **tools:** add studio_fs_delete_file ([14c0cf3](https://github.com/nightnei/wordpress-developer-mcp-server/commit/14c0cf348a06ec993b90dd328b025ad69cea1216))
* **tools:** add studio_fs_write_file ([352e878](https://github.com/nightnei/wordpress-developer-mcp-server/commit/352e878e0ecd0ef5ddbe126dd90faa04630b94d6))
* **tools:** add studio_site_create ([ec35cad](https://github.com/nightnei/wordpress-developer-mcp-server/commit/ec35cad754ec154db0cb4dd92348f59f68867676))
* **tools:** add studio_site_delete ([d930683](https://github.com/nightnei/wordpress-developer-mcp-server/commit/d930683d205c0737ef7630343b005bc1a3f7f61f))
* **tools:** add studio_site_set ([6133fbc](https://github.com/nightnei/wordpress-developer-mcp-server/commit/6133fbc3cb18018d1a8d5166acbe683fac5b21c8))
* **tools:** add studio_site_start ([7457343](https://github.com/nightnei/wordpress-developer-mcp-server/commit/7457343d481432e596c401340854d9bab5ccebad))
* **tools:** add studio_site_status ([5a39596](https://github.com/nightnei/wordpress-developer-mcp-server/commit/5a39596b58edb443816b667096af1a73987c6e42))
* **tools:** add studio_site_stop ([4347b7b](https://github.com/nightnei/wordpress-developer-mcp-server/commit/4347b7b06210e9a9c97d48f671a273d8526c5b32))
* **tools:** add wp-cli ([43021e6](https://github.com/nightnei/wordpress-developer-mcp-server/commit/43021e680129ce4c9e3b673e08ed004cbbe8b556))
* **tools:** return json for sites list ([f1e1aa9](https://github.com/nightnei/wordpress-developer-mcp-server/commit/f1e1aa98074713bb38d2487a3b34aee49b3c6563))
* **uninstall.sh:** add claude restart and optional removing files ([edbde5a](https://github.com/nightnei/wordpress-developer-mcp-server/commit/edbde5ad4a2ae3392550683ea0509cea012ed714))
* **uninstall.sh:** add readme ([077d076](https://github.com/nightnei/wordpress-developer-mcp-server/commit/077d07621c7bb5f3f3bee70f0c1f67add0d76e3a))
* zero-setup installation with install.sh ([362dcc8](https://github.com/nightnei/wordpress-developer-mcp-server/commit/362dcc8c34261a78db467da64a80eb0e0fba63b3))


### Bug Fixes

* adjusted with the new repo name ([a01762f](https://github.com/nightnei/wordpress-developer-mcp-server/commit/a01762f79cd2abda0d004bd19ec1e5ee9cabfce3))
* **install.sh:** remove arm64 check ([ca94553](https://github.com/nightnei/wordpress-developer-mcp-server/commit/ca945534408dd50228e78f00a7b539aedee6ce69))
* **install.sh:** wpcom login ([c1fd94c](https://github.com/nightnei/wordpress-developer-mcp-server/commit/c1fd94cfcc703553dc15b936de4c25afdfbada28))
* **install.sh:** wpcom login i2 ([a3a2c4e](https://github.com/nightnei/wordpress-developer-mcp-server/commit/a3a2c4e0250d064bd408fd04e8e54bc68707f9f0))
* **tools:** handle case with no already created sites ([b1e1661](https://github.com/nightnei/wordpress-developer-mcp-server/commit/b1e1661bb911fea34cb60fe1722d4ff058af4c70))
* **tools:** improve also process of resolving paths in the whole codebase ([990cb7e](https://github.com/nightnei/wordpress-developer-mcp-server/commit/990cb7e7de52b8ab2f0c7d00b3c08055822a22f3))
* **tools:** improve process of resolving paths ([00c9856](https://github.com/nightnei/wordpress-developer-mcp-server/commit/00c98568ef77c8fa06bcd24b91883b1de20992f2))
* **tools:** provide homedir to assistant ([44885cb](https://github.com/nightnei/wordpress-developer-mcp-server/commit/44885cbc0050a780a6709ade5a3906fec9204b71))
* **tools:** share wp-admin credentials and add instruction for auto-login ([9b30cdd](https://github.com/nightnei/wordpress-developer-mcp-server/commit/9b30cddded88771db0fb4758a79f6279b964a389))
* **tools:** spaces are respected for wp-cli ([d4f9e25](https://github.com/nightnei/wordpress-developer-mcp-server/commit/d4f9e2530df1cef4b75d957ddef1905d7df7f4dd))
* **uninstall.sh:** clean up Claude ([3773a38](https://github.com/nightnei/wordpress-developer-mcp-server/commit/3773a3801a8ceebf774a67f453944ebe3070fe8d))
* **uninstall.sh:** remove installation directory ([2de833d](https://github.com/nightnei/wordpress-developer-mcp-server/commit/2de833d09f6f7ff75d565b46f7e22fac3c75f7b6))
* **uninstall.sh:** remove installation directory ([40c9b6b](https://github.com/nightnei/wordpress-developer-mcp-server/commit/40c9b6b1cb90e6afda6f66d2af14f0ad322390aa))
* **uninstall.sh:** remove sites ([5eea83f](https://github.com/nightnei/wordpress-developer-mcp-server/commit/5eea83fa5bd49820ffb92875a362cb388fa85821))
* **uninstall.sh:** remove sites directory ([74a651f](https://github.com/nightnei/wordpress-developer-mcp-server/commit/74a651fe5096a781fd7a6b5d94dc0ca2e6074dcd))
* **uninstall:** check if studio is installed and dont remove sites ([7ef9e6c](https://github.com/nightnei/wordpress-developer-mcp-server/commit/7ef9e6c7559341379c048f79d046096715403f04))
* **uninstall:** check number of sites and ask user should they be removed ([5d0b222](https://github.com/nightnei/wordpress-developer-mcp-server/commit/5d0b2229774e5ccc4f1e3d8d78cd4d0139039f7f))
