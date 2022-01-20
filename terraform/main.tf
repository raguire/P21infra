# Configure the Azure provider

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
        }
    }
    backend "azurerm" {
        resource_group_name  = "p21-eus2-np-sa"
        storage_account_name = "tfstateo1kwu"
        container_name       = "tfstate"
        key                  = "terraform.tfstate"
    }
   required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

variable "prefix" {

  default = "webnp"

}

resource "azurerm_resource_group" "rg" {

  name     = "p21-eus2-np"

  location = "eastus2"

}



resource "azurerm_network_security_group" "nsg" {

  name                = "p21-nsg"

  location            = azurerm_resource_group.rg.location

  resource_group_name = azurerm_resource_group.rg.name

}



resource "azurerm_virtual_network" "vnet" {
  name                = "p21-eus2-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  #dns_servers         = ["10.0.0.4", "10.0.0.5"]
  tags = {

    environment = "Non Prod"

  }

}

resource "azurerm_subnet" "p21web" {
  name                 = "p21-web"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}



resource "azurerm_public_ip" "p21pip" {
  name                = "p21-web-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  tags = {
    environment = "Non Prod"
  }
}

resource "azurerm_network_interface" "mainweb" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "pocpip"
    subnet_id                     = azurerm_subnet.p21web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.p21pip.id
  }
}



resource "azurerm_virtual_machine" "mainvmweb" {

  name                  = "${var.prefix}-vm"

  location              = azurerm_resource_group.rg.location

  resource_group_name   = azurerm_resource_group.rg.name

  network_interface_ids = [azurerm_network_interface.mainweb.id]

  vm_size               = "Standard_DS1_v2"



  # Uncomment this line to delete the OS disk automatically when deleting the VM

  # delete_os_disk_on_termination = true



  # Uncomment this line to delete the data disks automatically when deleting the VM

  # delete_data_disks_on_termination = true



  storage_image_reference {

    publisher = "Canonical"

    offer     = "UbuntuServer"

    sku       = "16.04-LTS"

    version   = "latest"

  }

  storage_os_disk {

    name              = "myosdisk1"

    caching           = "ReadWrite"

    create_option     = "FromImage"

    managed_disk_type = "Standard_LRS"

  }

  os_profile {

    computer_name  = "p21web1"

    admin_username = "testadmin"

    admin_password = "Password1234!"

  }

  os_profile_linux_config {

    disable_password_authentication = false

  }

  tags = {

    environment = "Non Prod"

  }

}

resource "azurerm_managed_disk" "data" {
  name                 = "${var.prefix}-vm-data"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = azurerm_virtual_machine.mainvmweb.id
  lun                = "10"
  caching            = "ReadWrite"
}

resource "azurerm_managed_disk" "logs" {
  name                 = "${var.prefix}-vm-logs"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

resource "azurerm_virtual_machine_data_disk_attachment" "logs" {
  managed_disk_id    = azurerm_managed_disk.logs.id
  virtual_machine_id = azurerm_virtual_machine.mainvmweb.id
  lun                = "20"
  caching            = "ReadWrite"
}
