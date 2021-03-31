module MOD_CON

  !-----------------------------------------------------------------------------
  ! CON Component.
  !-----------------------------------------------------------------------------

  use ESMF
  use NUOPC
  use iso_c_binding
  use conduit
  use mod_interface

  implicit none

  private

  public GridToNode

  !-----------------------------------------------------------------------------
  contains
  !-----------------------------------------------------------------------------

  subroutine GridToNode(grid, vm, rc)
    type(ESMF_Grid), intent(in) :: grid
    type(ESMF_VM), intent(in) :: vm
    integer, intent(out) :: rc

    type(C_PTR) :: cnode
    integer :: csys, typeKind
    integer :: dimCount, tile, dim
    integer :: localPet, petCount, comm
    !TODO: currently only works for single tile for each local DE
    integer :: localDE = 0
    integer, allocatable :: maxIndex(:), totalCount(:)
    !TODO: currently works for one dimensional pointers
    integer(ESMF_KIND_I4), pointer :: fptrI4(:)
    integer(ESMF_KIND_I8), pointer :: fptrI8(:)
    real(ESMF_KIND_R4), pointer :: fptrR4(:)
    real(ESMF_KIND_R8), pointer :: fptrR8(:)
    character(ESMF_MAXSTR) :: str

    !TODO: Only query center stagger locations
    type(ESMF_StaggerLoc) :: staggerloc = ESMF_STAGGERLOC_CENTER
    type(ESMF_TypeKind_Flag) :: coordTypeKind
    type(ESMF_CoordSys_Flag) :: coordSys

    rc = ESMF_SUCCESS

    ! create node
    cnode = conduit_node_create()

    ! add MPI COMM_WORLD
    call ESMF_VMGet(vm, localPet=localPet, petCount=petCount, &
         mpiCommunicator=comm, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call conduit_node_set_path_int32(cnode, "mpi_comm", comm)
    call conduit_node_set_path_int32(cnode, "localPet", localPet)

    ! retrieve grid information
    call ESMF_GridGet(grid, coordTypeKind=coordTypeKind, &
         dimCount=dimCount, coordSys=coordSys, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! add coordSys to node, consistent with ESMPy
    if (coordSys == ESMF_COORDSYS_CART) csys = 0
    if (coordSys == ESMF_COORDSYS_SPH_DEG) csys = 1
    if (coordSys == ESMF_COORDSYS_SPH_RAD) csys = 2
    call conduit_node_set_path_int32(cnode, "coord_sys", csys)

    ! add max_index to node
    if (.not. allocated(maxIndex)) then
       allocate(maxIndex(dimCount))
       maxIndex = 0
    end if

    call ESMF_GridGet(grid, localDE, tile=tile, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call ESMF_GridGet(grid, tile, staggerloc, maxIndex=maxIndex, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call conduit_node_set_path_int32_ptr(cnode, "max_index", maxIndex, int8(dimCount))

    ! add coord_typekind to node, consistent with ESMPy
    if (coordTypeKind == ESMF_TYPEKIND_I4) typeKind = 3
    if (coordTypeKind == ESMF_TYPEKIND_I8) typeKind = 4
    if (coordTypeKind == ESMF_TYPEKIND_R4) typeKind = 5
    if (coordTypeKind == ESMF_TYPEKIND_R8) typeKind = 6
    call conduit_node_set_path_int32(cnode, "coordTypeKind", typeKind)

    ! add coordinate data to node
    if (.not. allocated(totalCount)) then
      allocate(totalCount(dimCount))
      totalCount(:) = 1
    end if

    do dim = 1, dimCount
      write(str, fmt='(A,I1)') 'arrDim_', dim
      ! NOTE: ESMF_GridGetCoord does not support I4 and I8 but ESMPy supports
      if (coordTypeKind == ESMF_TYPEKIND_R4) then
        call ESMF_GridGetCoord(grid, localDE=localDE, staggerloc=staggerloc, &
             coordDim=dim, farrayPtr=fptrR4, totalCount=totalCount, rc=rc)
        if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, &
            file=__FILE__)) &
            return  ! bail out
        call conduit_node_set_path_float32_ptr(cnode, trim(str), fptrR4, int8(product(totalCount, dim=1)))
      else if (coordTypeKind == ESMF_TYPEKIND_R8) then
        call ESMF_GridGetCoord(grid, localDE=localDE, staggerloc=staggerloc, &
             coordDim=dim, farrayPtr=fptrR8, totalCount=totalCount, rc=rc)
        if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, &
            file=__FILE__)) &
            return  ! bail out
        call conduit_node_set_path_float64_ptr(cnode, trim(str), fptrR8, int8(product(totalCount, dim=1)))
      end if
    end do

    ! print detailed information about node
    !call conduit_node_print_detailed(cnode)

    !call conduit_node_save(cnode, "test.json", "json")
    ! read from json
    !r_val = conduit_node_fetch_path_as_float64(cnode2,"a");
    !cn_1_test = conduit_node_fetch_existing(cn,"normal/path");

    ! pass node to Python
    call conduit_fort_to_py(cnode)

    ! destroy node object
    !call conduit_node_destroy(cnode)

  end subroutine GridToNode

end module MOD_CON
