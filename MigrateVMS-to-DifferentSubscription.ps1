#**Disclaimer**: This sample script is not supported 
 
#Definir essas variaveis antes de começar
#Provide the subscription Id of the subscription where managed disk exists
Login-AzureRmAccount
$sourceSubscriptionId=''

#Provide the name of your resource group where managed disk exists
$sourceResourceGroupName=''

#Provide the subscription Id of the subscription where managed disk will be copied to
#If managed disk is copied to the same subscription then you can skip this step
$targetSubscriptionId=''

#Name of the resource group where snapshot will be copied to
$targetResourceGroupName=''

#Location of the resources. MUST BE The same location for the two subscriptions
$location = ""

#Deste ponto em diante não é necessário editar
#cria tabela
$tabName = "SampleTable"

#Create Table object
$table = New-Object system.Data.DataTable “$tabName”

#Define Columns
$col1 = New-Object system.Data.DataColumn Name,([string])
$col2 = New-Object system.Data.DataColumn oldid,([string])
$col3 = New-Object system.Data.DataColumn newid,([string])

#Add the Columns
$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)

#Create a row
$row = $table.NewRow()

Write-host "Selecting Source Subscription..." -ForegroundColor Yellow 

#Set the context to the subscription Id where Managed Disk exists
Select-AzureRmSubscription -SubscriptionId $sourceSubscriptionId

Write-host "Listing source Managed Disks..." -ForegroundColor Yellow 

#Get the source managed disk list
#$managedDisk= Get-AzureRMDisk -ResourceGroupName $sourceResourceGroupName -DiskName $managedDiskName
$SourceMDlist = Get-AzureRmDisk -ResourceGroupName $sourceResourceGroupName

Write-host "Listing source VMs..."
#get the source VM list
$Sourcevmlist = Get-AzureRmVM -ResourceGroupName $sourceResourceGroupName


Write-host "Selecting Destination Subscription with existing VNET..." -ForegroundColor White -BackgroundColor Red
Select-AzureRmSubscription -SubscriptionId $targetSubscriptionId
Write-host "Listing source Vnet..." -ForegroundColor Yellow 
#get the source Virtual Network
$Sourcevnet = Get-AzureRmVirtualNetwork | Out-GridView -PassThru

Write-host "Listing source Availability Sets..." -ForegroundColor Yellow 

#get the source Availability Set
Select-AzureRmSubscription -SubscriptionId $sourceSubscriptionId 
$SourceAvSetList = Get-AzureRmAvailabilitySet -ResourceGroupName $sourceResourceGroupName

Write-host "Listing source Network Interfaces..." -ForegroundColor Yellow 
#get the source Network Interface
$SourceNICList = Get-AzureRmNetworkInterface -ResourceGroupName $sourceResourceGroupName

#Create new resource group into new subscription
Write-host "Selecting Target Subscription..." -ForegroundColor Yellow 
#Set the context to the subscription Id where managed disk will be copied to
#If snapshot is copied to the same subscription then you can skip this step
Select-AzureRmSubscription -SubscriptionId $targetSubscriptionId

Write-host "Creating new Resource Group..." -ForegroundColor Yellow 
#Create new resource group into new subscription
New-AzureRmResourceGroup -Name $targetResourceGroupName -Location $location

Write-host "Copying Managed disks to the new subscription using Snapshots..." -ForegroundColor Yellow 
#Create a new managed disk in the target subscription and resource group
foreach ($md in $SourceMDlist) 
{
$r = $table.NewRow()
$diskConfig = New-AzureRmDiskConfig -SourceResourceId $md.Id -Location $md.Location -CreateOption Copy -SkuName $md.Sku.Name
$tempdisk = New-AzureRmDisk -Disk $diskConfig -DiskName $md.name -ResourceGroupName $targetResourceGroupName 
$r.name = $md.Name
$r.oldid = $md.Id
$r.newid = $tempdisk.Id 
#Add the row to the table
$table.Rows.Add($r)
}
#get list of the new Managed Disks in the target Subscription and resource group
$newMDlist = Get-AzureRmDisk -ResourceGroupName $targetResourceGroupName

#Write-host "Creating new Virtual Network and Subnets on the target subscription with the same configuration..."

#Create a new Vnet in the  target subscription and resource group
#$newVnet = New-AzureRmVirtualNetwork -ResourceGroupName $targetResourceGroupName -Name $Sourcevnet.Name -AddressPrefix $Sourcevnet.AddressSpace.AddressPrefixes -Location $location

#foreach ($sn in $Sourcevnet.Subnets)
#{
#$r = $table.NewRow()
#$newVnet = Add-AzureRmVirtualNetworkSubnetConfig -Name $sn.name -VirtualNetwork $newVnet -AddressPrefix $sn.addressprefix
#Set-AzureRmVirtualNetwork -VirtualNetwork $newVnet
#$newVnet = Get-AzureRmVirtualNetwork -ResourceGroupName $targetResourceGroupName -Name $newVnet.Name
#$r.name = $sn.Name
#$r.oldid = $sn.Id
#$r.newid = (Get-AzureRmVirtualNetworkSubnetConfig -Name $sn.name -VirtualNetwork $newVnet).id
#Add the row to the table
#$table.Rows.add($r)

#}
#Set-AzureRmVirtualNetwork -VirtualNetwork $newVnet

#get list of the new Managed Disks in the target Subscription and resource group
#$newVnet = Get-AzureRmVirtualNetwork -ResourceGroupName $targetResourceGroupName -Name $newVnet.Name
#$newsubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $newVnet

Write-host "Moving Availability Sets..." -ForegroundColor Yellow 

#create new availability set in the new Resource Group and Target Subscription
foreach ($avs in $SourceAvSetList) 
{
$r = $table.NewRow()
#Create New Availability Set with the same configuration of the old 
$tempavs = New-AzureRmAvailabilitySet -ResourceGroupName $targetResourceGroupName -Name $avs.name -Location $location -Sku $avs.Sku -PlatformUpdateDomainCount $avs.PlatformUpdateDomainCount -PlatformFaultDomainCount $avs.PlatformFaultDomainCount
$r.name = $avs.Name
$r.oldid = $avs.Id
$r.newid = $tempavs.Id 
#Add the row to the table
$table.Rows.Add($r)

}

#get a list of the new availabilityset
$newavset = Get-AzureRmAvailabilitySet -ResourceGroupName $targetResourceGroupName

Write-host "Copying Network Interfaces to the new subscription..." -ForegroundColor Yellow 

foreach ($oldnic in $SourceNICList)
{
$r = $table.NewRow()
$oldipcfg = Get-AzureRmNetworkInterfaceIpConfig -NetworkInterface $oldnic

$tempsn = $table.Rows | ? {($_.oldid -eq ($oldipcfg.Subnet.Id))}
#create New NIC with the same configuration of the old NIC
$newnic = New-AzureRmNetworkInterface -Name $oldnic.name -ResourceGroupName $targetResourceGroupName -Location $location -SubnetId $Sourcevnet.Subnets.Id 
$r.name = $oldnic.Name
$r.oldid = $oldnic.Id
$r.newid = $newnic.Id 
#Add the row to the table
$table.Rows.Add($r)

}

Write-host "Creating the VMs using the existing Managed Disks, Network Interfaces and Availability Set..." -ForegroundColor Yellow 


foreach ($oldvm in $Sourcevmlist)
{
#verifica se VM tem AVSet
if ($oldvm.AvailabilitySetReference.id -ne $null)
{
$newav = $table.Rows | ? {($_.oldid -eq ($oldvm.AvailabilitySetReference.id))}
#Initialize virtual machine configuration with Availability Set
$VirtualMachine = New-AzureRmVMConfig -VMName $oldvm.name -VMSize $oldvm.HardwareProfile.VmSize -AvailabilitySetId $newav.newid

}
else
{
#Initialize virtual machine configuration
$VirtualMachine = New-AzureRmVMConfig -VMName $oldvm.name -VMSize $oldvm.HardwareProfile.VmSize
}

$disco = $table.Rows | ? {($_.name -eq $oldvm.StorageProfile.OsDisk.Name)}

#verifica se a VM é WIndows ou Linux
if ($oldvm.OSProfile.LinuxConfiguration -ne $null)
{
#Use the Managed Disk Resource Id to attach it to the virtual machine. Please change the OS type to linux if OS disk has linux OS
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -ManagedDiskId $disco.newid -CreateOption Attach -Linux
}
else
{
#Use the Managed Disk Resource Id to attach it to the virtual machine. Please change the OS type to linux if OS disk has Windows OS
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -ManagedDiskId $disco.newid -CreateOption Attach -Windows
}
#verifica se a a VM tem datadisk
if ($oldvm.StorageProfile.DataDisks -ne $null) 
{
foreach ($datadisk in $oldvm.StorageProfile.DataDisks)
{
$Datadisco = $table.Rows | ? {($_.name -eq $datadisk.Name)}
#attach the existing DataDisk
    Add-AzureRmVMDataDisk -VM $VirtualMachine -Name $datadisk.Name -Lun $datadisk.Lun -DiskSizeInGB $datadisk.DiskSizeGB -Caching ReadOnly -CreateOption Attach -ManagedDiskId $Datadisco.newid
    
}
}

#Attach existing NIC to the VM
$NovaNic = $table.Rows | ? {($_.oldid -eq $oldvm.NetworkProfile.NetworkInterfaces.Id)}
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NovaNic.newid

#Create the virtual machine with Managed Disk
New-AzureRmVM -VM $VirtualMachine -ResourceGroupName $targetResourceGroupName -Location $location

}    
Write-Host "New environment created successful"  -ForegroundColor Yellow 


