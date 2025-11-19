# Run Godot tests and capture output
$ErrorActionPreference = "Continue"

# Set UTF-8 encoding for proper Unicode character display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Run godot and capture all output
& godot --headless --path . --script res://addons/auto_structured/tests/run_tests.gd 2>&1 | ForEach-Object {
    if ($_ -is [System.Management.Automation.ErrorRecord]) {
        Write-Host $_.Exception.Message
    } else {
        Write-Host $_
    }
}

# Exit with the godot process exit code
exit $LASTEXITCODE
