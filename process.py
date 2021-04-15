import conduit
import conduit.relay as relay
import numpy as np
from mpi4py import MPI

# get mpi info
comm_id = my_node["mpi_comm"]
comm = MPI.Comm.f2py(comm_id)
comm_rank = relay.mpi.rank(comm_id)
comm_size = relay.mpi.size(comm_id)

# get data from fortran
data_from_fort = my_node['pmsl']

# update the data, simply chnage the value in the middle
# note that this uses MPI and we are modifiying data in each processor
indx = int(data_from_fort.shape[0]/2)-1
data_from_fort[indx] = data_from_fort[indx]*2.0

# create new node
pmsl = conduit.Node()

# set data, pmsl is the name of the ESMF field that will be updated in fortran side
pmsl['data'].set_external(data_from_fort)
