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
  public FieldToNode
  public NodeToField
  public FieldUpdateByPython

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

  subroutine FieldToNode(field, vm, rc)
    type(ESMF_Field), intent(in) :: field
    type(ESMF_VM), intent(in) :: vm
    integer, intent(out) :: rc

    ! local variables
    type(C_PTR) :: cnode
    integer :: comm, localPet, petCount, dimCount
    integer :: elementCount(2), localElementCount(2)
    character(ESMF_MAXSTR) :: fname
    type(ESMF_TypeKind_Flag) :: typekind
    real(ESMF_KIND_R8), pointer :: fptr(:,:)

    ! get comm world
    call ESMF_VMGet(vm, localPet=localPet, petCount=petCount, &
         mpiCommunicator=comm, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! query type of field
    call ESMF_FieldGet(field, name=fname, typekind=typekind, dimCount=dimCount, &
         elementCount=elementCount, localElementCount=localElementCount, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out

    ! get pointer out of field
    if (typekind == ESMF_TYPEKIND_R8) then
      call ESMF_FieldGet(field, farrayPtr=fptr, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          return  ! bail out
    end if

    ! create node
    cnode = conduit_node_create()

    call conduit_node_set_path_int32(cnode, "mpi_comm", comm)
    call conduit_node_set_path_int32_ptr(cnode, "global_shape", elementCount, int8(dimCount))
    call conduit_node_set_path_int32_ptr(cnode, "local_shape", localElementCount, int8(dimCount))
    call conduit_node_set_path_float64_ptr(cnode, trim(fname), fptr, int8(product(localElementCount, dim=1)))

    ! pass node to Python
    call conduit_fort_to_py(cnode)
    !call conduit_node_print(cnode)

    ! return updated data
    call NodeToField(field, vm, rc)

  end subroutine FieldToNode

  subroutine NodeToField(field, vm, rc)
    type(ESMF_Field), intent(in) :: field
    type(ESMF_VM), intent(in) :: vm
    integer, intent(out) :: rc

    ! local variables
    type(C_PTR) :: cnode
    integer :: localPet, petCount, dimCount
    integer :: localElementCount(2)
    character(ESMF_MAXSTR) :: fname
    !type(ESMF_TypeKind_Flag) :: typekind
    real(8), pointer :: fptr1d(:)
    real(ESMF_KIND_R8), pointer :: fptr2d(:,:)

    ! get comm world
    call ESMF_VMGet(vm, localPet=localPet, petCount=petCount, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! query type of field
    call ESMF_FieldGet(field, name=fname, dimCount=dimCount, localElementCount=localElementCount, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out

    ! get node from Python
    cnode = conduit_fort_from_py(trim(fname))
    !call conduit_node_print_detailed(cnode)

    ! get pointer out of node
    call conduit_node_fetch_path_as_float64_ptr(cnode,"data",fptr1d)
    
    ! reshape pointer
    write(*,fmt='(A,3I8)') "ptr1d => ", localPet, lbound(fptr1d, dim=1), ubound(fptr1d, dim=1)
    write(*,fmt='(A,3I8)') "ptr2d => ", localPet, localElementCount
    !write(*,fmt='(A,I8,F20.15)') "ptr1d => ", localPet, fptr1d(int((ubound(fptr1d, dim=1)-lbound(fptr1d, dim=1)+1)/2))
    !fptr2d(1:localElementCount(1),1:localElementCount(2)) => fptr1d

    ! update ESMF field
    call ESMF_FieldGet(field, farrayPtr=fptr2d, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
    fptr2d(1:localElementCount(1),1:localElementCount(2)) => fptr1d

  end subroutine NodeToField

  subroutine FieldUpdateByPython(field, vm, rc)
    type(ESMF_Field), intent(in) :: field
    type(ESMF_VM), intent(in) :: vm
    integer, intent(out) :: rc

    ! local variables
    type(C_PTR) :: cnode_send, cnode_recv
    integer :: i, j, k, comm, localPet, petCount, dimCount
    integer :: elementCount(2), localElementCount(2)
    character(ESMF_MAXSTR) :: fname
    type(ESMF_TypeKind_Flag) :: typekind
    real(ESMF_KIND_R8), pointer :: fptr1d(:), fptr2d(:,:)

    ! get comm world
    call ESMF_VMGet(vm, localPet=localPet, petCount=petCount, &
         mpiCommunicator=comm, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
 
    ! query type of field
    call ESMF_FieldGet(field, name=fname, typekind=typekind, dimCount=dimCount, &
         elementCount=elementCount, localElementCount=localElementCount, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out

    ! get pointer out of field
    if (typekind == ESMF_TYPEKIND_R8) then
      call ESMF_FieldGet(field, farrayPtr=fptr2d, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          return  ! bail out
    end if

    ! create node
    cnode_send = conduit_node_create()

    ! add information to node
    call conduit_node_set_path_int32(cnode_send, "mpi_comm", comm)
    call conduit_node_set_path_int32_ptr(cnode_send, "global_shape", elementCount, int8(dimCount))
    call conduit_node_set_path_int32_ptr(cnode_send, "local_shape", localElementCount, int8(dimCount))
    call conduit_node_set_path_float64_ptr(cnode_send, trim(fname), fptr2d, int8(product(localElementCount, dim=1)))

    ! interact with Python
    cnode_recv = conduit_interact(cnode_send, trim(fname))

    ! get pointer out of node
    call conduit_node_fetch_path_as_float64_ptr(cnode_recv, "data", fptr1d)

    ! update ESMF field
    !write(*,fmt='(A,I8,F20.16,I8)') "ptr1d => ", localPet, fptr1d(int((ubound(fptr1d, dim=1)-lbound(fptr1d, dim=1)+1)/2)), int((ubound(fptr1d, dim=1)-lbound(fptr1d, dim=1)+1)/2)
    !fptr2d(1:localElementCount(1),1:localElementCount(2)) => fptr1d
    write(*,fmt='(A,3I8)') "ptr1d => ", localPet, lbound(fptr1d, dim=1), ubound(fptr1d, dim=1)
    write(*,fmt='(A,5I8)') "ptr2d => ", localPet, lbound(fptr2d, dim=1), ubound(fptr2d, dim=1), lbound(fptr2d, dim=2), ubound(fptr2d, dim=2)

    k = 1
    do j = lbound(fptr2d, dim=2), ubound(fptr2d, dim=2) 
    do i = lbound(fptr2d, dim=1), ubound(fptr2d, dim=1)
      fptr2d(i,j) = fptr1d(k)
      k = k+1
    end do
    end do

  end subroutine FieldUpdateByPython

end module MOD_CON
