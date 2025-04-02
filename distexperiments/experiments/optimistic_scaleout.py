import sys

import config
from distexprunner import *

NUMBER_NODES = 2
BIN_DIR = "/proj/sandstorm-PG0/ashfaq/repos/RDMA_synchronization/build/frontend"
IF_NAME = "ens2f0np0"

parameter_grid = ParameterGrid(
    # worker=[1,2,4,8,16,32,64,128,256,512,1024,2048],
    worker=[1,2],
    locks=[200000],
    options=["-CRC", "-farm" , "-versioning", "-broken", "-pessimistic"],
    footer=["-nofooter","-footer"],
    blocks=[256, 16384],

)


# @reg_exp(servers=config.server_list[:NUMBER_NODES])
# def compile(servers):
#     servers.cd("/home/tziegler/rdma_synchronization/build/")
#     cmake_cmd = f'cmake -D CMAKE_C_COMPILER=gcc-11 -D CMAKE_CXX_COMPILER=g++-11 -DCMAKE_BUILD_TYPE=Release ..'
#     procs = [s.run_cmd(cmake_cmd) for s in servers]
#     assert(all(p.wait() == 0 for p in procs))
#
#     make_cmd = f'sudo make -j'
#     procs = [s.run_cmd(make_cmd) for s in servers]
#     assert(all(p.wait() == 0 for p in procs))
    

@reg_exp(servers=config.server_list[:NUMBER_NODES], params=parameter_grid, raise_on_rc=True, max_restarts=1)
def locking_benchmark(servers, worker,locks, options, footer, blocks):    
    servers.cd(BIN_DIR)        
    cmds = []
    cmd = f'numactl --membind=0 --cpunodebind=0 sudo ip netns exec {IF_NAME} ./optmistic_benchmark -ownIp={servers[0].ibIp} -storage_node -worker={worker} -lock_count={locks} -dramGB=10'
    cmds += [servers[0].run_cmd(cmd)]

    work = worker
    numberNodes=1
    if worker >=4:
        work = int(worker/4)
        numberNodes=4
    
    for i in range(1, numberNodes+1):
        cmd = f'numactl --membind=0 sudo ip netns exec {IF_NAME} ./optmistic_benchmark -ownIp={servers[i].ibIp} -all_worker={worker} -worker={work} -csvFile="optimistic_benchmark_scaleout_new.csv" -run_for_seconds=30 -tag={worker} -nopinThreads -lock_count={locks} {options} {footer} -block_size={blocks}'
        cmds += [servers[i].run_cmd(cmd)]
        
    if not all(cmd.wait() == 0 for cmd in cmds):
        return Action.RESTART
