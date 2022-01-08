# Unix_Automation
Repo for automating Unix tasks 

Monitor memory 

watch -d free -m

From <https://mkyong.com/linux/how-to-display-the-real-time-memory-usage-in-linux/> 

Monitor HD 
% iostat -dx /dev/sda 5


mkdir -p $HOME/.ssh
chmod 0700 $HOME/.ssh
ssh-keygen -t rsa

To validate certs iics run 
cd /app/ipaas/isa/apps/jdk/1.8.0_252_SA/jre/lib/security
/app/ipaas/isa/jdk/jre/bin/keytool -list -v -keystore cacerts > cacert_list.out
