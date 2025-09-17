# Resource Monitoring for GSP Windows Agent

This document describes the resource monitoring functionality added to the GSP Windows Agent.

## Overview

The resource monitoring system collects machine and process statistics for game servers managed by the agent and stores them in a MySQL database. This allows for tracking resource usage over time.

## Features

- **Machine Statistics**: CPU usage, memory usage, disk usage
- **Process Statistics**: Per-game-server resource monitoring 
- **Windows/Cygwin Compatible**: Uses Windows commands (wmic) when Linux /proc/* is not available
- **Selective Monitoring**: Only monitors processes for game servers that have startup files
- **Scheduled Collection**: Configurable collection interval (default 5 minutes)

## Database Configuration

Configure the database connection in `Cfg/Config.pm`:

```perl
# Resource stats database configuration
stats_db_host => 'your_mysql_host',
stats_db_user => 'your_mysql_user', 
stats_db_pass => 'your_mysql_password',
stats_db_name => 'your_database_name',
stats_table_prefix => 'gsp_',
stats_frequency_minutes => '5',
```

## Database Schema

The system creates three tables:

1. **gsp_machines**: Machine registry
2. **gsp_machine_samples**: Machine resource samples over time
3. **gsp_process_samples**: Process resource samples over time

Import the SQL files from the `DB/` directory to create these tables.

## Game Server Detection

The system only monitors processes for game servers that have corresponding files in the `startups/` directory. Startup files are named in the format:

```
IP-PORT
```

For example:
- `127.0.0.1-27015` (for a game server on localhost port 27015)
- `192.168.1.100-7777` (for a game server on 192.168.1.100 port 7777)

The contents of each startup file should contain the game server's installation path.

## Windows Compatibility

The monitoring functions automatically detect the platform:

- **Linux/Cygwin**: Uses /proc/stat, /proc/meminfo, etc.
- **Windows**: Uses wmic commands for resource collection

This ensures the agent works properly in both environments.

## Installation

1. Configure database settings in `Cfg/Config.pm`
2. Import database schema from `DB/*.sql` files
3. Ensure DBI and DBD::mysql Perl modules are installed
4. Restart the agent

The resource monitoring will automatically start when the agent launches if database settings are configured.

## Monitoring

The system will:

1. Generate a unique machine ID based on hostname and MAC address
2. Register the machine in the database
3. Collect resource statistics every 5 minutes (configurable)
4. Store machine-level stats (CPU, memory, disk)
5. Store process-level stats for game servers only

## Dependencies

- DBI (Perl database interface)
- DBD::mysql (MySQL driver for DBI)
- Digest::MD5 (for machine ID generation)
- POSIX (for timestamp formatting)

## Examples

Sample startup files are included in the `startups/` directory for reference.