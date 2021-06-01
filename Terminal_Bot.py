import paramiko,time,sys,json,os,pandas
########################################################################################################################
################################################### parms  #############################################################
proxy = None
Port = 22
Username = open('').read() #put username in txt file 
Pwd = open('').read() #put password in txt file 
Host = ''
keys= '' #file with ssh keys
sudo_user = '' #optional parameter fill in if using sudo option in function must be passed as full command ie: sudo su - user
path = ''
download_from = ""
download_to = ""

## put commands one line at a time ##
listofcommands=f'''
'''
########################################################################################################################

def exec_remote_cmds(commands,waittime,sudo = None):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(hostname=Host, username=Username, password=Pwd, port=Port, key_filename=keys) #instantiate connection

    shell = client.invoke_shell()

    if sudo != None :
        shell.send(sudo)
        time.sleep(waittime)
        receive_buffer = shell.recv(1024)

    receive_buffer = ""
    shell.send(commands)
    status = shell.recv_ready()
    cmple = []
    return_cursor_item = None
    page = 0
    time.sleep(1)
    while return_cursor_item != '$':
            #status ==False :
        time.sleep(1)
        output = shell.recv(1024).decode("utf-8")
        for i in output.split(';',) :
            cmple.append(''.join(s for s in i ))
        print (output)
        #print("Page :", page)
        return_cursor = [s for s in output.splitlines()][-1].strip() ## needed for custom exit subroutine since paramiko hangs the session
        return_cursor_item = [l for l in return_cursor][len([l for l in return_cursor])-1] ## needed for custom exit subroutine since paramiko hangs the session
        status+= shell.recv_ready()
        page +=1
    print("Pages Read:",page)
    #for i in cmple: print(i.replace('[01','').replace('\n',''))


def download_remote_file(remotepath:str,localpath:str,waittime:int,sudo:str = None):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(hostname=Host, username=Username, password=Pwd, port=Port, key_filename=keys) #instantiate connection

    shell = client.invoke_shell()

    if sudo != None :
        shell.send(sudo)
        time.sleep(waittime)
        receive_buffer = shell.recv(1024)

    sftp = client.open_sftp()
    sftp.get(remotepath,localpath)
    while not os.path.exists(localpath):
        time.sleep(waittime)
    sftp.close()

def write_file_to_remote(remotepath:str,localpath:str,waittime:int,sudo:str = None):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(hostname=Host, username=Username, password=Pwd, port=Port, key_filename=keys) #instantiate connection

    shell = client.invoke_shell()

    if sudo != None :
        shell.send(sudo)
        time.sleep(waittime)
        receive_buffer = shell.recv(1024)

    sftp = client.open_sftp()
    sftp.put(localpath,remotepath)
    while not os.path.exists(remotepath):
        time.sleep(waittime)
    sftp.close()

exec_remote_cmds(listofcommands,1,sudo_user)#sudo user is option must by passed as full sudo su - if used
#write_file_to_remote(download_from,download_to,1,sudo_user) 
#download_remote_file(download_to,download_from,1)
