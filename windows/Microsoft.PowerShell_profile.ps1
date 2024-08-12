# remove the classic powershell 'welcome'
clear-host

# customize the prompt using the most unintuitive process imaginable
function prompt {
    $cyan = "Cyan"
    $white = "White"
    $green = "Green"
    # lol
    $orange = [System.ConsoleColor]::DarkYellow

    $path = $PWD.Path

    $branch = ""

    if (Test-Path .git) {
        $branch = & git rev-parse --abbrev-ref HEAD
        $branch = " ($branch)"
    }

    Write-Host -ForegroundColor $cyan $path -NoNewline
    Write-Host -ForegroundColor $green $branch -NoNewline
    Write-Host -ForegroundColor $orange " >" -NoNewline

    return " "
}

# set default open path, because if we open windows shell we're likely working on our main project
Set-Location -Path "$HOME\Desktop\dev\unity-ufo"
