from distexprunner import ServerList, Server


SERVER_PORT = 20005


server_list = ServerList(
    # fill in
    Server('node0', 'sm110p-10s10608.wisc.cloudlab.us', SERVER_PORT, ibIp='10.10.1.1', sibIP='10.10.1.1', ssdPath="/dev/md0"),
    Server('node1', 'sm110p-10s10607.wisc.cloudlab.us', SERVER_PORT, ibIp='10.10.1.2', sibIP='10.10.1.2', ssdPath="/dev/md0 "),
    Server('node06', 'c06.lab.dm.informatik.tu-darmstadt.de', SERVER_PORT, ibIp='172.18.94.60', sibIP='172.18.94.61', ssdPath="/dev/md0"),
    
    Server('node04', 'c04.lab.dm.informatik.tu-darmstadt.de', SERVER_PORT, ibIp='172.18.94.40', sibIP='172.18.94.41', ssdPath="/dev/md127"),
    Server('node05', 'c05.lab.dm.informatik.tu-darmstadt.de', SERVER_PORT, ibIp='172.18.94.50', sibIP='172.18.94.51', ssdPath="/dev/md0"),
    Server('node02', 'c02.lab.dm.informatik.tu-darmstadt.de', SERVER_PORT, ibIp='172.18.94.20', sibIP='172.18.94.21', ssdPath="/dev/md0"),
    Server('node01', 'c01.lab.dm.informatik.tu-darmstadt.de', SERVER_PORT, ibIp='172.18.94.10', sibIP='172.18.94.11', ssdPath="/dev/md0"),
)
