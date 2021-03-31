module mod_interface

  !-----------------------------------------------------------------------------
  ! FORTRAN BINDING INTERFACE FOR ...
  !-----------------------------------------------------------------------------

  use, intrinsic :: iso_c_binding, only: c_ptr

  implicit none

  interface
    subroutine conduit_fort_to_py(cnode) bind(C, name="conduit_fort_to_py")
      use iso_c_binding
      implicit none
      type(C_PTR), value, intent(IN) :: cnode
    end subroutine conduit_fort_to_py
  end interface

  !-----------------------------------------------------------------------------
  contains
  !-----------------------------------------------------------------------------

end module mod_interface
