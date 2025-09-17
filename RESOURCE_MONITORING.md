# GSP Agent Windows Resource Monitoring Implementation

## Overview

This implementation replicates the resource statistics gathering and MySQL submission logic from the Linux agent (`ogp_agent.pl` in the unstable branch) into the Windows agent. The system uses the same database schema and data format as the Linux agent, ensuring compatibility with the OGP web panel.

## Implementation Details

### 1. Scheduling System
- **Method**: Uses proper cron scheduling via `Schedule::Cron` module (same as Linux agent)
- **Frequency**: Controlled by `stats_frequency_minutes` configuration value
- **Function**: `collect_and_submit_resource_stats()` is scheduled as a cron job
- **Schedule Format**: `*/X * * * *` where X is the frequency in minutes

### 2. Resource Gathering

#### CPU Usage
- **Cygwin**: Uses `/proc/stat` for accurate CPU percentage calculation
- **Windows**: Uses `wmic cpu get loadpercentage` command
- **Method**: Samples CPU twice with 1-second interval for accuracy

#### Memory Usage
- **Cygwin**: Uses `/proc/meminfo` for detailed memory statistics
- **Windows**: Uses `wmic OS get TotalVisibleMemorySize,FreePhysicalMemory`
- **Data**: Tracks total, used, and percentage of system memory

#### Disk Usage
- **Cygwin**: Uses `df -lP` command for filesystem information
- **Windows**: Uses `wmic logicaldisk where "DeviceID='C:'" get Size,FreeSpace`
- **Scope**: Monitors C: drive (primary system drive)

#### System Uptime
- **Cygwin**: Uses `/proc/uptime` for system uptime in seconds
- **Windows**: Uses `wmic os get lastbootuptime` and calculates uptime from boot time
- **Format**: Returns uptime in seconds since boot

#### Load Average
- **Cygwin**: Uses `/proc/loadavg` for system load averages
- **Windows**: Simulates load average using CPU usage percentage (load = cpu_usage / 100)
- **Values**: Provides 1-minute, 5-minute, and 15-minute load averages

### 3. Game Server Process Monitoring

#### Server Detection
- **Method**: Uses startup folder (`GAME_STARTUP_DIR`) to identify configured game servers
- **Format**: Startup files are named `IP-PORT` and contain server configuration
- **Scope**: Only monitors processes that have corresponding startup files (managed by OGP)

#### Process Identification
- **Windows**: Uses `wmic process get ProcessId,Name,CommandLine,PageFileUsage,WorkingSetSize`
- **Matching**: Processes are matched to game servers by:
  - Command line containing server path
  - Process listening on configured server port
  - Command line containing server executable name

#### Process Metrics
- **Memory**: Working set size and page file usage
- **CPU**: Basic process information (complex CPU calculation requires performance counters)
- **Network**: Listening ports via `netstat -ano`
- **Storage**: Server folder size via `dir` command (limited for performance)

### 4. Database Integration

#### Connection
- **Driver**: Uses DBI with MySQL driver (`DBI:mysql`)
- **Configuration**: Uses same config values as Linux agent:
  - `stats_db_host`, `stats_db_user`, `stats_db_pass`, `stats_db_name`
  - `stats_table_prefix`, `stats_frequency_minutes`

#### Schema
- **Tables**: Creates same three tables as Linux agent:
  - `gsp_machines`: Machine registration
  - `gsp_machine_samples`: System resource samples
  - `gsp_process_samples`: Process-level resource samples
- **Compatibility**: Uses identical schema to Linux agent for web panel compatibility

#### Data Format
- **Machine ID**: Generated from hostname + MAC address + install path
- **Timestamps**: MySQL DATETIME format (`NOW()`)
- **Metrics**: Same units and precision as Linux agent

## Configuration

### Database Settings (in `Cfg/Config.pm`)
```perl
stats_db_host => 'mysql.hostname.com',        # MySQL server hostname
stats_db_user => 'username',                  # MySQL username
stats_db_pass => 'password',                  # MySQL password
stats_db_name => 'panel',                     # Database name
stats_table_prefix => 'gsp_',                 # Table prefix
stats_frequency_minutes => '5',               # Collection frequency in minutes
```

### Dependencies

#### Required Perl Modules
- `DBI` - Database interface
- `DBD::mysql` - MySQL driver for DBI
- `Schedule::Cron` - Task scheduling (already included)
- `Digest::MD5` - Machine ID generation (already included)
- `Time::Local` - Time parsing for Windows uptime

#### Windows Commands
- `wmic` - Windows Management Instrumentation Command-line
- `netstat` - Network statistics
- `dir` - Directory listing and size calculation

#### Cygwin Commands (if available)
- `df` - Disk space information
- Access to `/proc/stat`, `/proc/meminfo`, `/proc/uptime`, `/proc/loadavg`

## Usage

### Automatic Startup
The resource monitoring system automatically starts when the OGP Agent starts if:
1. Database configuration is present and valid
2. `stats_frequency_minutes` is set to a positive integer
3. Required Perl modules are installed

### Manual Testing
Use the included demo script to test functionality:
```bash
perl OGP/resource_monitoring_demo.pl
```

### Logs
Resource monitoring events are logged to:
- Main agent log (`ogp_agent.log`)
- Scheduler log (`Schedule/scheduler.log`)

## Compatibility

### Web Panel
- **Full Compatibility**: Uses same database schema as Linux agent
- **Mixed Environments**: Windows and Linux agents can submit to same database
- **Charts/Reports**: Web panel displays data from both agent types identically

### Windows Versions
- **Windows Server 2008 R2+**: Full compatibility with wmic commands
- **Windows 10/11**: Full compatibility
- **Cygwin Environment**: Enhanced accuracy using Linux-style /proc filesystem

### Agent Versions
- **Backward Compatible**: Does not break existing agent functionality
- **Optional Feature**: Runs only when database is configured
- **Resource Efficient**: Minimal overhead, runs every 5+ minutes by default

## Troubleshooting

### Common Issues

1. **Database Connection Fails**
   - Verify MySQL server is accessible
   - Check firewall settings for MySQL port (3306)
   - Validate credentials and database name

2. **No Resource Data**
   - Check that `stats_frequency_minutes` is set to a positive integer
   - Verify DBI and DBD::mysql modules are installed
   - Check agent and scheduler logs for errors

3. **Process Monitoring Empty**
   - Ensure game servers have startup files in `startups/` directory
   - Verify game servers are actually running
   - Check that process command lines contain server paths

4. **Permission Errors**
   - Ensure OGP Agent has permission to execute wmic commands
   - Verify database user has INSERT privileges on stats tables

### Diagnostic Commands
```bash
# Test database connection
perl -MDBI -e "my \$dbh = DBI->connect('DBI:mysql:database=panel;host=hostname', 'user', 'pass') or die DBI->errstr; print 'Connected successfully\n';"

# Test wmic availability
wmic cpu get loadpercentage /value

# Test resource functions
perl OGP/resource_monitoring_demo.pl
```

## Security Considerations

1. **Database Credentials**: Store securely in `Cfg/Config.pm` with appropriate file permissions
2. **Command Execution**: Uses only safe, read-only system commands
3. **Process Access**: Only monitors processes related to configured game servers
4. **Performance Impact**: Minimal - designed for 5+ minute collection intervals

## Future Enhancements

1. **Enhanced Windows Metrics**: Use Windows Performance Counters for more detailed CPU/disk I/O
2. **Network Statistics**: Implement network interface statistics via WMI
3. **Service Monitoring**: Monitor Windows services in addition to processes
4. **Event Log Integration**: Capture relevant Windows Event Log entries