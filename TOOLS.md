# Site Management

### 🛠 Sites

- List, create, start, stop, and delete WordPress sites
- Configure PHP/WordPress versions, custom domains, HTTPS, Xdebug
- Check site status and authentication

### 📁 File System Operations

- List directories, read, write, and delete files
- Safely sandboxed to site directories only

### 🌐 Preview Sites

- Create, update, list, and delete shareable preview links (\*.wp.build)

### 🔄 WordPress.com Sync

- Fetch WordPress.com sites live from the authenticated account
- Push local WordPress sites to WordPress.com
- Pull WordPress.com sites into local WordPress sites

### ⚡ WP-CLI Integration

- Full access to WP-CLI commands: plugins, themes, posts, pages, users, options, database, and more
- Install plugins, create content, manage settings — all through natural language

### 🔄 MCP Updates

- Check for and install updates to the MCP server without leaving your AI agent

## Available Tools

| Category     | Tools                                                                                                                                     |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| **Sites**    | `wpdev_site_list`, `wpdev_site_status`, `wpdev_site_start`, `wpdev_site_stop`, `wpdev_site_create`, `wpdev_site_delete`, `wpdev_site_set` |
| **Files**    | `wpdev_fs_list_dir`, `wpdev_fs_read_file`, `wpdev_fs_write_file`, `wpdev_fs_delete`                                                       |
| **Previews** | `wpdev_preview_list`, `wpdev_preview_create`, `wpdev_preview_update`, `wpdev_preview_delete`                                              |
| **Sync**     | `wpdev_wpcom_site_list`, `wpdev_site_push`, `wpdev_site_pull`                                                                             |
| **Auth**     | `wpdev_auth_status`, `wpdev_auth_logout`                                                                                                  |
| **WP-CLI**   | `wpdev_wp` — run any WP-CLI command (plugins, themes, posts, users, options, etc.)                                                        |
| **Updates**  | `wpdev_check_for_mcp_updates`, `wpdev_update_mcp`                                                                                         |
