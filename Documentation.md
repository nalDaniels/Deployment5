# Purpose:
To learn how to use Terraform to create and configure infrastructure and use Jenkins to deploy application. Previously, we have been manually creating infrastructure using both the graphical user interface and the command line. Unfortunately, those practices do not permit reusability or sharability. Terraform allows us to make continuous updates to our infrastructure, share our files with other members of our team, and design a blueprint that has been tested for reuse. Additionally, with the use of a version control system, you are able to keep track of different versions and roll it back to the previous state if the new infrastructure does not work.

After creating the infrastructure, I learned how to deploy a three-tier retail banking application onto an EC2 instance via a ssh tunnel using Jenkins. 

# Steps to Deployment:
## 1. Use Terraform to Create Infrastructure
I created the network infrastructure including a vpc, 2 public subnets, 2 security groups, 2 availability zones, a route table, and an internet gateway. Then, I provisioned an EC2 instance in each subnet - one with Jenkins installed on it. I created 2 security groups because the applications on each instance required different ports. The Jenkins instance runs on port 8080. The retail banking application's web and application servers run on gunicorn on port 8000. You can take a look at my main.tf file here: 

It is important to be aware that creating a VPC creates a default route table. To configure the default route table, you have to use that particular resource instead of the route table resource. This avoids creating an additional resource instead of just editing what has already been created.

### Issues:
When I set up my security group for the Jenkins server to be open on port 8080, I was unable to connect to my instance. The IP address on port 8080 led to Jenkins, but the actual instance was unaccessible. I resolved this by opening up port 22. I assume this worked because EC2 connect creates an ssh connection to access the IP address' terminal. 

### Optimization:
To improve this deployment, I would place the Jenkins server in a private subnet. This would add additional levels of security for the application code and files Jenkins clones from our repository. Therefore, the Jenkins server can only be accessed via EC2 connect points or bastion hosts rather than the internet. 

Since the application appears to be an internal company facing application instead of customer facing, so I would advise placing the application in a private subnet. Furthermore, the application holds sensitive information about customers and accounts, so using a private subnet would make the application more secure and protect it from hacking by only enabling authorized users access to the app.

The public subnets are still necessary as they will have the NAT gateway, which allows the applications in the private subnet to route traffic outside of the VPC. 

## 2. Use The Jenkins User
### Purpose: 
SSH into the second instance using your Jenkins user
I created a password for Jenkins user using sudo passwd jenkins and signed into the user, using `sudo su - jenkins -s /bin/bash'. I ran a build in Jenkins in order to locate the application files it cloned. 

Inside the Jenkins user, I  generated a key-pair and copied the key in id_pubrsa in my Jenkins server into the authorized_keys file of the second instance. Next, I tested out the ssh connection from the Jenkins server to the second instance. 

After exiting the Jenkins user, I ran sudo apt install -y software-properties-common && sudo add-apt-repository -y ppa:deadsnakes/ppa && sudo apt install -y python3.7 && sudo apt install -y python3.7-venv - in both instances. This installed software repositories that exist outside of the ones available in Ubuntu, python, and python's virtual environment.

### Optimization:
I could have the previous commands to a script and inputted them as user-data when creating infrastructure in Terraform. 

## 3.  Get Code and Update Jenkinsfile
I run a build to determine the location of the application files Jenkins clones, so that I could to the ssh into the second server and run the setup script, which exists in the build directory, in order to deploy the application 
I tested out commands in the terminal before adding it to the Jenkinsfilev1.

I created a second branch and added this command to the Jenkinsfilev1
#### ssh -T ubuntu@10.0.2.90 </var/lib/jenkins/workspace/Deployment5_main/setup.sh
Then I,
git add .
git commit -m "Updated jenkinsfilev1"
git switch main
git merge second 
git push to Github

## 4. Create a Multibranch Pipeline and Run a Build
I installed 'pipeline keep running' to keep the retail banking application deployed after the build. I routed the step looking for the jenkinsfile to jenkinsfilev1. we were able to sucessfully run the pipeline and deploy the retail banking application

### Console Output:
The ‘build’ stage is creating a virtual environmentJenkins used git to clone the repository and fetch the latest commits. The build stage created a virtual environment using python3, activated that test environment, installed python's package manager and all of the packages in the requirements.txt that are necessary for the application to run. The test stage activated the test environment, executed tests, and saved the results in test-reports/results.xml

The deploy stage ssh'd into the second server and successfully deployed the retail application onto it. 
<img width="1215" alt="Screen Shot 2023-10-14 at 1 15 54 AM" src="https://github.com/nalDaniels/Deployment5/assets/135375665/965d63b0-345f-4c4b-809e-1eebf19c8d10">

### Deployment Script
In the script a python virtual environment was created and activated and the repository was cloned onto the second EC2 instance. Within the application files directory, pip installed the packages necessary to deploy the application and gunicorn. Then, it ran the database.py and load_data.py files, which created an SQLite database and populated it with account information. Finally, it started the gunicorn server.

### Issues
Initially, I was unable to get my setup.sh script to run. After looking at the logs, I realized that python3-pip needed to be installed to download the packages necessary to deploy the application be sure the install python3-pip.

## 5. Change an HTML File, Update Jenkinsfilev2, and Rerun Build
In my second branch, I added ssh -T ubuntu@10.0.2.90 </var/lib/jenkins/workspace/Deployment5_main/pkill.sh and ssh -T ubuntu@10.0.2.90 </var/lib/jenkins/workspace/Deployment5_main/setup2.sh commands to the jenkinsfilev1 in order for these scripts to run in the instance hosting the application. 

I also changed the header in the home.html file, updated the setup2.sh script to pointing to the correct repository with the updates, and added my terraform files.
Then, I
git add .
git commit -m "Updated jenkinsfilev2 and added terraform files"
git switch main
git merge second
git push

I changed the configuration to point to jenkinsfilev2 and reran the build. 

### Console Output
I ran the commands in the ‘Clean’ stage and found that the script searched the processes for gunicorn and if the PID was a number other than 0, meaning the process was active, then it killed the process. Plainly, it kills any running gunicorn processes. However, when I ran the command there was more than one gunicorn process, so this script would only rid of one using the head -n 1 command. Though, maybe killing one process, kills them all.

The setup2.sh removed the previously cloned repository and cloned the repository with the new home.html changes. Then, the file ran a script that successfully deployed the application to the EC2 instance.

<img width="1237" alt="Screen Shot 2023-10-14 at 1 47 15 AM" src="https://github.com/nalDaniels/Deployment5/assets/135375665/0aaba6d4-602d-4eac-b45e-5753fda88a72">


## 6. Install CloudWatch and Create Alarms
### Purpose:
Monitoring the Jenkins server and retail banking application allows me to be aware of resource usage and determine whether or not I need to scale the infrastructure up or down. 

For the instance running the Jenkins application, I created an alert to monitor CPU usage. I chose this metric because I've noticed that when running builds the CPU tends to go up. In order to ensure I am not under-provisioning the EC2 instance hosting Jenkins, I created an alarm for when the CPU goes beyond 70%.

For the instance running the retail banking application, I created alerts for memory, CPU, disk storage, and disk input/output time if these measurements go over 60% or 150ms. I chose these metrics for these reasons: on the EC2 instance we are running gunicorn and SQLite; we are reading and writing to the database. 

### Reminder:
Add the CloudWatch IAM role to the EC2 after installing CloudWatch.

### Alarm Output:
After creating a customer and account in the application, the disk storage alarm was set off. This indicates that for this application we need an EC2 instance with more disk storage.

# Resources:
Find my system design for this deployment here:
