# Hyper-V-VM-ToExternalStorage
PowerShell script to copy a Hyper-V virtual machine to external storage

This script is designed to aid in moving a Hyper-V virtual machine to an external drive.
It will provide you with a selection of virtual machines that are running in Hyper-v.
After your selection, it will shutdown the virtual machine if it is running and copy the virtual machine
files to a temporary directory.  After this is completed, it will remove the virtual machine from Hyper-V,
and copy the virtual machine files back to the original location (just files, not virtual drives).

The second part is scanning the computer for usable storage to copy the virtual machine to.  It will
look for all usb drives that have capacity greater than the current contents of the virtual machine that is
to be moved.  If the drive is not NTFS format, it will prompt to format the drive to NFTS to ensure large files
can be copied to the device.

This script is designed for a series of tutorials I am planning for home users in building virtual machine
routers.  It is used to demonstrate that a VM can be moved to external storage and ran from it, providing
the virtual machine does not have heavy IO demand for the drive.
