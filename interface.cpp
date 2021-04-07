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

    // my_node is set in here statically, it will be used to access node under python
    pyintp->set_dict_object(py_mod_dict, py_node, "my_node"); 

    // trigger script
    bool err = pyintp->run_script_file("process.py", py_mod_dict);
  }

  //-----------------------------------------------------------------------------
  // access node passed from python to fortran 
  //----------------------------------------------------------------------------
  conduit_node* conduit_fort_from_py(const char *py_name) {
    // create python interpreter
    PythonInterpreter *pyintp = init_python_interpreter();

    // trigger script
    bool err = pyintp->run_script_file("process.py");

    //std::cout << "py_name = " << py_name << std::endl;
    //std::ostringstream oss;
    //oss << py_name << " = conduit.Node()" << std::endl
    //    << "data = np.array(range(10), dtype='float64')" << std::endl
    //    << py_name << "['data'].set_external(data)" << std::endl
    //    << "print('Hello from python, I created:')" << std::endl
    //    << "print(" << py_name << ")" << std::endl;

    //pyintp->run_script(oss.str());

    // get global dict and fetch wrapped conduit node
    PyObject *py_mod_dict =  pyintp->global_dict();

    // create py object to get the conduit node
    PyObject *py_obj = pyintp->get_dict_object(py_mod_dict,
                                               py_name);

    // check error if requested conduit node does not exist
    if (!PyConduit_Node_Check(py_obj)) {
      //std::cout << "failed to access " << py_name << std::endl;
      //return NULL;;
    }

    // get cpp ref from python node
    conduit::Node *cpp_res = PyConduit_Node_Get_Node_Ptr(py_obj);

    // return the c pointer
    return conduit::c_node(cpp_res);
  }

  //----------------------------------------------------------------------------
  // send & recv 
  //----------------------------------------------------------------------------
  conduit_node* conduit_interact(conduit_node *data, const char *py_name) {
    // create python interpreter
    PythonInterpreter *pyintp = init_python_interpreter();

    // get global dict and insert wrapped conduit node
    PyObject *py_mod_dict =  pyintp->global_dict();

    // get cpp ref to passed node
    conduit::Node &n = conduit::cpp_node_ref(data);

    // create py object to wrap the conduit node
    PyObject *py_node = PyConduit_Node_Python_Wrap(&n,
                                                   0); // python owns => false

    // my_node is set in here statically, it will be used to access node under python
    pyintp->set_dict_object(py_mod_dict, py_node, "my_node");

    // trigger script
    bool err = pyintp->run_script_file("process.py", py_mod_dict);

    // get global dict and fetch wrapped conduit node
    py_mod_dict =  pyintp->global_dict();

    // create py object to get the conduit node
    PyObject *py_obj = pyintp->get_dict_object(py_mod_dict,
                                               py_name);

    // get cpp ref from python node
    conduit::Node *cpp_res = PyConduit_Node_Get_Node_Ptr(py_obj);

    // return the c pointer
    return conduit::c_node(cpp_res);
  }
}
