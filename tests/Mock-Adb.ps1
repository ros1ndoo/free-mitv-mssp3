param($P, $s, [Parameter(ValueFromRemainingArguments)][string[]]$CommandArgs)
$ErrorActionPreference = 'Stop'
$file = $env:FTV_MOCK_FILE
$state = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -AsHashtable
$command = $CommandArgs -join ' '
$response = ''
switch -Regex ($command) {
    '^get-state$' { $response = 'device'; break }
    '^shell getprop (.+)$' { $response = $state.props[$Matches[1]]; break }
    '^shell cmd package resolve-activity ' { $response = "priority=0`n$($state.home)"; break }
    '^shell dumpsys package (.+)$' {
        $name = $Matches[1]
        if ($state.packages.ContainsKey($name)) { $response = "User 0: installed=true hidden=false enabled=$($state.packages[$name])" }
        break
    }
    '^shell settings get global (.+)$' { $response = $state.animations[$Matches[1]]; break }
    '^shell am start ' { $response = 'Status: ok'; break }
    '^shell pm (\S+) --user 0 (\S+)$' {
        $operation = $Matches[1]; $name = $Matches[2]
        if ($env:FTV_MOCK_FAIL -eq $name) { Write-Output 'Error: injected failure'; exit 1 }
        $map = @{'default-state'=0;enable=1;disable=2;'disable-user'=3;'disable-until-used'=4}
        $state.packages[$name] = $map[$operation]; $response = 'Package state changed'; break
    }
    '^shell settings put global (\S+) (\S+)$' { $state.animations[$Matches[1]] = $Matches[2]; break }
    '^shell settings delete global (\S+)$' { $state.animations[$Matches[1]] = 'null'; break }
    '^shell cmd package set-home-activity --user 0 (\S+)$' { $state.home = $Matches[1]; $response = 'Success'; break }
    '^shell input keyevent KEYCODE_HOME$' { break }
    default { Write-Output "Error: comando no simulado: $command"; exit 1 }
}
$state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $file
Write-Output $response
exit 0
