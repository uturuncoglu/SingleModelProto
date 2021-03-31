#import sys
#sys.path.insert(0,'/usr/local/lib/python3.9/site-packages')
#print(sys.path)
import conduit
from mpi4py import MPI
comm_id = my_node["mpi_comm"]
comm = MPI.Comm.f2py(comm_id)
print(comm_id)
print(comm)
