﻿<#
.Synopsis
   Logon History
.DESCRIPTION
   Show interactive user logon history of the users on a target computer from the Security log.

   CREDITS
    (dot)NET XML event message parsing from freenode#powershell IRC User redyey
    Parameter names and .NET object refactoring from freenode#powershell IRC User Jaykul
.EXAMPLE
   Get-LogonHistory 15-31
   Returns the User Name, Firstname, Surename, Logon time, logoff time
.NOTES
   LOGON event Log Name: Security, Source: Microsoft-Windows-Security-Auditing, ID: 4624
   LOGOFF event Log Name: Security, Source: Microsoft-Windows-Security-Auditing, ID: 4634
   WORKSTATION_LOCKED event Log Name: Security, Source: Microsoft-Windows-Security-Auditing, ID: 4800
   WORKSTATION_UNLOCKED event Log Name: Security, Source: Microsoft-Windows-Security-Auditing, ID: 4801
   Logon Types: Interactive = 2; Network = 3; Batch = 4; Service = 5; Unlock = 7;
      NetworkCleartext = 8; NewCredentials = 9; RemoteInteractive = 10; CachedInteractive = 11 
      [ref]http://www.windowsecurity.com/articles-tutorials/misc_network_security/Logon-Types.html
   Getting details from event logs:
   [ref]http://blogs.technet.com/b/ashleymcglone/archive/2013/08/28/powershell-get-winevent-xml-madness-getting-details-from-event-logs.aspx
#>
function Get-LogonHistory
{
    [CmdletBinding(DefaultParameterSetName='Default')]
    Param
    (
        # Target computer name
        [Parameter(Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [string]
        $ComputerName = 'localhost'

        , # How many days before today should I search. By default get yesterdays records
        [Parameter(ParameterSetName='History', position=1)]
        [int]
        $PastDays = 1

        , # How many days logons would you like to See
        [Parameter(ParameterSetName='History', position=2)]
        [int]
        $Days = 1

        , # Just get todays records
        [Parameter(ParameterSetName='Default')]
        [switch]
        $Today
    )

    Begin
    {
        if($Today)
        {
            $PastDays = 0
        }

        # Use the .Date property to reset the time to 00:00:00
        [datetime]$StartDay = (Get-Date).AddDays( - $PastDays).Date
        [datetime]$StopDay = $StartDay.AddDays($Days).Date

        Write-Verbose "From $ComputerName get Logon events between $StartDay and $StopDay"
    }
    Process
    {
        try
        {
            # Grab the events from a remote computer
            $EventLog = Get-WinEvent -ComputerName $ComputerName -FilterHashtable @{
                            Logname='Security';
                            Id=4624;
                            StartTime=$StartDay;
                            EndTime=$StopDay
                        } -ErrorAction Stop
        } catch {
            Write-Error "$ComputerName cannot be found"
        }

        Write-Verbose "Got $($EventLog.count) event(s)"

        # Parse out the event message data
            # NOTE: Special credit redyey, I would not have thought to get the event message out
            # ...   into properties on the event object to return.
        ForEach ($Event in $EventLog) {

            $xml = [xml]$Event.ToXml()
            $ShortName = $xml.Event.EventData

            ForEach ($data in $ShortName.Data)
            {
                $Event |
                    Add-Member -Force -NotePropertyName $data.name -NotePropertyValue $data.'#text'
            }
        }

        # logon type 2 is an 'Interactive' session, i.e. a real user at the keyboard
        $EventLog | 
            Where-Object -Property logonType -EQ 2 |
            Select-Object @{
                    name='User Name';
                    expression={ $_.TargetUserName }
                },@{
                    name='Logon Time';
                    expression={ $_.TimeCreated }
                },@{
                    name='Computer';
                    expression={ $_.SubjectUserName }
                }
    }
    End
    {
    }
}