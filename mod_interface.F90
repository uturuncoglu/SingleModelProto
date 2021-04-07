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

    function c_conduit_fort_from_py(name) result(res) bind(C, name="conduit_fort_from_py")
      use iso_c_binding
      implicit none
      character(kind=C_CHAR), intent(IN) :: name(*)
      type(C_PTR) :: res
    end function c_conduit_fort_from_py

    function c_conduit_interact(cnode, name) result(res) bind(C, name="conduit_interact")
      use iso_c_binding
      implicit none
      type(C_PTR), value, intent(IN) :: cnode
      character(kind=C_CHAR), intent(IN) :: name(*)
      type(C_PTR) :: res
    end function c_conduit_interact

  end interface

  !-----------------------------------------------------------------------------
  contains
  !-----------------------------------------------------------------------------

  !-----------------------------------------------------------------------------
  ! Note this method exists to apply fortran trim to passed string
  ! before passing to the c api
  !-----------------------------------------------------------------------------
  function conduit_fort_from_py(name) result(res)
    use iso_c_binding
    implicit none
    character(*), intent(IN) :: name
    type(C_PTR) :: res
    !---
    res = c_conduit_fort_from_py(trim(name) // C_NULL_CHAR)
  end function conduit_fort_from_py

  function conduit_interact(cnode, name) result(res)
    use iso_c_binding
    implicit none
    type(C_PTR), value, intent(IN) :: cnode
    character(*), intent(IN) :: name
    type(C_PTR) :: res
    !---
    res = c_conduit_interact(cnode, trim(name) // C_NULL_CHAR)
  end function conduit_interact

end module mod_interface
