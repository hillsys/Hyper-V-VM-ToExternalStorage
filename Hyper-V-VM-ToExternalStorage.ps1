
#   Copyright 2017 Paul Hill  paul@hillsys.org
#
#
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#
#   you may not use this file except in compliance with the License.
#
#   You may obtain a copy of the License at
#
#
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#
#
#   Unless required by applicable law or agreed to in writing, software
#
#   distributed under the License is distributed on an "AS IS" BASIS,
#
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#
#   See the License for the specific language governing permissions and
#
#   limitations under the License.


# Get the list of the virtual machines on this computer
$vmList = Get-VM

# We will store the values of the virtual machine names here
# It is an empty array
$vmNameList = @()

# This dialog box will be used later in the program
$yesNoSelection = [System.Management.Automation.Host.ChoiceDescription[]]("Yes","No")

# Cycle through each virtual machine and add the name to the empty array
foreach($vm in Get-VM) {
    $vmNameList += $vm.VMName
}

# Make a menu selection based on the virtual machine names for the user to select
$vmSelection = [System.Management.Automation.Host.ChoiceDescription[]]($vmNameList)

# Get the index of the user selection from the dialog box
$userSelection = $Host.UI.PromptForChoice('Select VM','What VM do you wish to remove from Hyper-V?', $vmSelection,0)

# If the virtual machine is running notify the user a shutdown is proceding
if($vmList[$userSelection].State -eq "Running"){
    echo ("Shutting down vm:  " + $vmNameList[$userSelection] + " .")
    Stop-VM -Name $vmNameList[$userSelection]
}

# If the virtual machine is off
if($vmList[$userSelection].State -eq "Off"){
    
    # Set the directory the vm resides in
    $vmDirectory = $vmList[$userSelection].Path
    
    # Default Virtual Machine folder
    $default = $vmDirectory + "\Virtual Machines"

    # Set the id of the vm to find files for
    $vmId = $vmList[$userSelection].VMId
    
    # Set the temp directory to copy vm files to
    $temp = $vmDirectory + "\Temp"
    
    # Prompt the user if they are sure about removing the vm
    $proceedWithRemoval = $Host.UI.PromptForChoice('VM Removal','Proceed with removing ' + $vmNameList[$userSelection] + '?', $yesNoSelection,0)
    
    # Procede with removal of vm that was selected
    if($proceedWithRemoval -eq 0){

        # Set bool to vm files found to fales
        $foundVMFiles = $false

        # If there is no temp directory remove it
        if(Test-Path -Path $temp) {
            Remove-Item $temp -Recurse -Force
        }

        # Create the temporary directory
        New-Item $temp -ItemType directory

        # Get all child objects of vm directory and copy all files that match vm id
        Get-ChildItem -Recurse $vmDirectory | ForEach-Object {
            
            # If the child object matches vm id, save location, copy to temp, and set that files were found
            if($_.BaseName -eq $vmId){
                $foundVMFiles = $true
                Copy-Item $_.FullName -Destination ($temp + "\" + $_.Name) -Force
            }
        }

        # If files were found
        if($foundVMFiles) {
            
            # Remove the vm from Hyper-V
            Remove-vm -Name $vmNameList[$userSelection] -Force

            # Create the Virtual Machines folder is not present
            if(-Not(Test-Path $default)) {
                New-Item $default -ItemType directory
            }

            # Copy items back to original directory, temp becomes a backup copy
            Get-ChildItem $temp | ForEach-Object {
                Copy-Item $_.FullName -Destination ($default + "\" + $_.Name)
            }

            # Check to see if proceed with moving vm to external storage
            $proceedWithMove = $Host.UI.PromptForChoice('VM Move','Proceed with moving to external storage?', $yesNoSelection,0)

            if($proceedWithMove -eq 0){
                
                # Set empty array to store all possible external drive letters, and assign none as first choice
                $externalDrives = @()
                $externalDrives += "None"

                # Set variable for hasExternalDrive to false
                $hasExternalDrive = $false

                # Get the size of the virtual machine and drives
                $spaceNeeded = (Get-ChildItem -Recurse $vmDirectory | Measure-Object -property length -sum).Sum                

                # Get removable drive objects and list those that have capacity
                Get-WmiObject Win32_Volume -Filter "DriveType='2'" | ForEach-Object {
                    if($_.Capacity -gt $spaceNeeded) {
                       $externalDrives += $_.DriveLetter
                       $hasExternalDrive = $true
                    }
                }

                # If there is an external drive that has capacity
                if($hasExternalDrive){
                    
                    # Get the drive the user wants to copy information to
                    $selectedDrive = $Host.UI.PromptForChoice('VM Move','Select external drive.', $externalDrives,0)

                    # The selectedDrive has to be greater than zero for it to be a valid choice
                    if($selectedDrive -gt 0) {

                        $selectedDriveFileSystem = (Get-WmiObject Win32_Volume -Filter "DriveLetter='$externalDrives[$selectedDrive]'").FileSystem

                        if($selectedDriveFileSystem -inotin "NTFS"){
                            # Request formating to NTFS, otherwise exit
                            $proceedWithFormat = $Host.UI.PromptForChoice('VM Move','External storage is not NTFS.  Format the drive?', $yesNoSelection,0)

                            if($proceedWithFormat -eq 0){
                                Format-Volume -DriveLetter $externalDrives[$selectedDrive].Substring(0,1)
                            }
                            else {
                                echo "Drive must be NTFS format.  Stopping all further actions."
                                exit
                            }
                        }

                        # Set the path and folder to copy to
                        $externalPath = $externalDrives[$selectedDrive] + "\" + $vmNameList[$userSelection]

                        # Check to see if it contains a directory for the virtual machine, if it does remove it
                        if(Test-Path $externalPath) {
                            Remove-Item $externalPath -Recurse -Force
                        }
                    
                        #Create the directory for the copy
                        New-Item $externalPath -ItemType directory

                        # Get all child objects of vm directory and copy all files to external drive
                        Get-ChildItem -Recurse -File $vmDirectory | ForEach-Object {
                            Copy-Item $_.FullName -Destination ($externalPath + "\" + $_.Name) -Force
                        }

                        echo "Operation completed.  You may delete the copy on your hard drive."
                    }
                    # Zero index of selectedDrive represents none were chosen
                    else {
                        echo "Stopping all further operations."
                    }
                }
                else {
                    echo "No external drive found, or none have enough capacity for move.  Stopping all further operations."
                }
            }
            else {
                echo "Stopping all further operations."
            }

        }
        # No files found and exit
        else {
            echo ("Unable to find associated files for virtual machine " + $vmNameList[$userSelection] + ".  Stopping all further actions.")
        }
    }
    # Inform the user all actions have stopped.
    else {
        echo "User stop action.  All further operations ceased."
    }
}
# Inform the user that shutdown was not possible on the vm.
else {
    echo "Unsuccessful in shutting vm " + $vmNameList[$userSelection] + " off.  All further operations stopped."
}