import conduit
import conduit.relay as relay
import conduit.relay.mpi
import numpy as np
from mpi4py import MPI



comm_id = my_node["mpi_comm"]
comm = MPI.Comm.f2py(comm_id)

comm_rank = relay.mpi.rank(comm_id)
comm_size = relay.mpi.size(comm_id)
#print(comm_rank, comm_size)

gshape = my_node['global_shape']
lshape = my_node['local_shape']
#print(gshape, np.prod(gshape), lshape)

#d = my_node.fetch('pmsl').dtype()
#print(conduit.DataType.id_to_name(d.id()))

#pmsl_global = conduit.Node() #conduit.Node(conduit.DataType.float64(np.prod(gshape)))
#print(pmsl_global)
#pmsl_local = my_node['pmsl']
#pmsl_shaped = pmsl.reshape(shape)
#print(pmsl_local)

#relay.mpi.all_gather(pmsl_local, pmsl_global, 0, comm=comm_id)
#if comm_rank == 0:
#    print(pmsl_global)


n = conduit.Node()
data = np.zeros((5,),dtype=np.float64)+comm_rank
n["a"] = data #comm_rank+1
print(n)
rcv = conduit.Node()
relay.mpi.gather_using_schema(n,rcv,0,comm_id)
if comm_rank == 0:
    print(rcv.number_of_children())
    #for v in rcv["a"].children():
    #    print(v.node())
    print(rcv[0]["a"])
    print(np.concatenate((rcv[0]["a"], rcv[1]["a"])))
    
