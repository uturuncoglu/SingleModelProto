import conduit
from mpi4py import MPI
comm_id = my_node["mpi_comm"]
comm = MPI.Comm.f2py(comm_id)
print(comm_id)
shape = my_node['shape']
pmsl = my_node['pmsl']
pmsl_shaped = pmsl.reshape(shape)
print(pmsl_shaped)
