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

### ⚡ WP-CLI Integration

- Full access to WP-CLI commands: plugins, themes, posts, pages, users, options, database, and more
- Install plugins, create content, manage settings — all through natural language

## Available Tools

| Category     | Tools                                                                                                                                            |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Sites**    | `studio_site_list`, `studio_site_status`, `studio_site_start`, `studio_site_stop`, `studio_site_create`, `studio_site_delete`, `studio_site_set` |
| **Files**    | `studio_fs_list_dir`, `studio_fs_read_file`, `studio_fs_write_file`, `studio_fs_delete`                                                          |
| **Previews** | `studio_preview_list`, `studio_preview_create`, `studio_preview_update`, `studio_preview_delete`                                                 |
| **Auth**     | `studio_auth_status`, `studio_auth_logout`                                                                                                       |
| **WP-CLI**   | `studio_wp` — run any WP-CLI command (plugins, themes, posts, users, options, etc.)                                                              |
