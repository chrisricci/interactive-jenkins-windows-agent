# Interactive Windows Agent with Jenkins on GCP 
The contents in this repo can be used to create a pipeline on Jenkins that will execute commands in an interactive Desktop in a Windows VM on GCP.

### Before you Begin
1. Have a GCP Project create with the appropriate networking and firewall rules in place to allow communication to your Jenkins Server.
2. You need an SSH Key and configure your GCP Project metadata: https://cloud.google.com/compute/docs/connect/add-ssh-keys#add_ssh_keys_to_project_metadata
3. Look through each script and update the variables and placeholders appropriately. Pay close attention to the use of GCP Project Name, GCP Networks/Subnetwork references, etc...
4. You will need to add the Public SSH key to the [windows-image-bootstrap.ps1](windows-image-bootstrap.ps1) script
5. Create a GCP Service Account that has permissions to create Virtual Machines. Export the Service Account Key and create it as a secret (Make sure the Kind is 'Secret File') and pay attention to the name as you reference it in the [pipeline.json](pipeline.json)
6. Create the SSH Key as a 'SSH Username with private key' credential in Jenkins

### Build your Linux VM Image
The Linux Bootstrap VM is used to dynamically create the Windows VM that will be running in Interactive Mode.
Update the [jenkins-linux-agent.json](jenkins-linux-agent.json) file by providing the appropriate values for region, zone, and project id
From a machine with Packer installed, run the following command:
```
./packer build -on-error=ask jenkins-linux-agent.json
```

### Build your Windows VM Image
The Windows VM Image will be bootstrapped with SSH, create a default 'Jenkins' OS User and create a scheduled task to start the agent.jar.
Before running this step, make sure the [windows-image-bootstrap.ps1](windows-image-bootstrap.ps1) is available to the machine you'll be running this build from and update the reference to this script, along with the GCP Project and networking references in the [jenkins-win-agent.json](jenkins-win-agent.json)
From a machine with Packer installed, run the following command:
```
./packer build -on-error=ask jenkins-win-agent.json
```

### Upload Startup Script to GCS
The Startup script will run when the Windows VM launches. This script will dynamically register the node as a Jenkins agent and create a script which the scheduled task will execute to start the agent.
Edit the [windows-startup-script.ps1](windows-startup-script.ps1) with the correct Jenkins Host URLs, credentials, etc... If the agent needs to connect through a proxy, specify values for agentHost/agentPort. If not, remove the `<tunnel>$agentHost`:$agentPort</tunnel>` from the $config variable.
Upload the script using gcsutil:
```
gcsutil cp windows-startup-script.ps1 gs://<bucketLocation>
```

### Configure Jenkins
Update the GCE Template to use the linux-bootstrap VM Image
Create a pipeline from [pipeline.json](pipeline.json)
Make sure to update the gcloud compute instance create command with the proper values for <project_id>, networking settings, and gcs storage location of the startup script.
