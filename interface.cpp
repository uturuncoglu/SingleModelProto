#include <mpi.h>
#include <conduit_relay_mpi.hpp>

#include <conduit.hpp>
#include <conduit_cpp_to_c.hpp>
#include "conduit_python.hpp"
#include "python_interpreter.hpp"

using namespace conduit;
using namespace std;
//-----------------------------------------------------------------------------
// -- begin extern C
//-----------------------------------------------------------------------------


// single python interp instance for our example module.
PythonInterpreter *interp = NULL;

extern "C" {

  // returns our static instance of our python interpreter
  // if not already inited initializes it
  PythonInterpreter *init_python_interpreter()
  {
      if( interp == NULL)
      {
          interp = new PythonInterpreter();
          if( !interp->initialize() )
          {
              std::cout << "ERROR: interp->initialize() failed " << std::endl;
             return NULL;
          }
          // setup for conduit python c api
          if(!interp->run_script("import conduit"))
          {
              std::cout << "ERROR: `import conduit` failed" << std::endl;
             return NULL;
          }

          if(import_conduit() < 0)
          {
             std::cout << "failed to import Conduit Python C-API";
             return NULL;
          }

          // Turn this on if you want to see every line
          // the python interpreter executes
          //interp->set_echo(true);
      }
      return interp;
  }

  //----------------------------------------------------------------------------
  // access node passed from fortran to python
  //----------------------------------------------------------------------------
  void conduit_fort_to_py(conduit_node *data) {
    // create python interpreter
    PythonInterpreter *pyintp = init_python_interpreter();

    //pyintp->add_system_path("/usr/local/lib/python3.9/site-packages");

    // get global dict and insert wrapped conduit node
    PyObject *py_mod_dict =  pyintp->global_dict();

    // get cpp ref to passed node
    conduit::Node &n = conduit::cpp_node_ref(data);

    // create py object to wrap the conduit node
    PyObject *py_node = PyConduit_Node_Python_Wrap(&n,
                                                   0); // python owns => false

    pyintp->set_dict_object(py_mod_dict, py_node, "my_node");

    // extract MPI communicator
    //int comm_id = n["mpi_comm"].as_int();
    //MPI_Comm comm = MPI_Comm_f2c(comm_id);
    //int myid = 0;
    //int ierr = MPI_Comm_rank(comm, &myid);
    //cout << "mpi_comm = " << comm_id << " myid = " << myid << endl;

    // read Python script and broadcase to all procs
    //Node n_py_src;
    //if (myid == 0) {
    //  ostringstream py_src;
    //  string script_fname = "process.py";
    //  ifstream ifs(script_fname.c_str());
    //  if (ifs.is_open()) {
    //    py_src << "# script from: " << script_fname << std::endl;
    //    copy(istreambuf_iterator<char>(ifs),
    //         istreambuf_iterator<char>(),
    //         ostreambuf_iterator<char>(py_src));
    //    n_py_src.set(py_src.str());
    //    ifs.close();
    //  }
    //}

    //relay::mpi::broadcast_using_schema(n_py_src, 0, comm);

    //n_py_src["source"] = n_py_src;

    // create py object to wrap the conduit node
    //PyObject *py_node = PyConduit_Node_Python_Wrap(&n_py_src,
    //                                               0); // python owns => false

    //
    // NOTE: we aren't checking pyintp->run_script return to simplify
    //       this example -- but you should check in real cases!
    //bool err = pyintp->run_script("print('Hello from Python, here is what you passed:')");
    //cout << err << endl;
    //if (err) {
    //  CONDUIT_ERROR(pyintp->error_message());
    //}
    //pyintp->run_script("print(my_node)");
    //pyintp->run_script("vals_view = my_node['values'].reshape(my_node['shape'])");
    //pyintp->run_script("print(vals_view)");

    //pyintp->run_script("import conduit");
    // m_running need to be true to see the output, it is in PythonInterpreter
    bool err = pyintp->run_script_file("process.py", py_mod_dict);
    //cout << emsg << endl;
    //pyintp->error_message();
    //bool err = pyintp->run_script(n_py_src["source"] , py_mod_dict);

    //string script = "from mpi4py import MPI;comm = MPI.COMM_WORLD;rank = comm.Get_rank();print(rank)";
    //int result = PyRun_SimpleString((char*)script.c_str());
    //cout<< "hoho"<< endl;

    // Finalize Python Interpreter
    //Py_Finalize();
  }

}
