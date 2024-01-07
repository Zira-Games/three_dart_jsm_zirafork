part of jsm_controls;

mixin DraggableObject {}

class DraggableMesh extends Mesh with DraggableObject {
  DraggableMesh(super.geometry, super.material);
}

class DraggableSprite extends Sprite with DraggableObject {
  DraggableSprite([super.material]);
}

class DragControls with EventDispatcher {
  late DragControls scope;

  bool enabled = false;
  bool transformGroup = false;
  Axis? moveAxis;
  List<Intersection> _intersections = <Intersection>[];
  Object3D? _selected;
  Object3D? _hovered;

  late String id;
  late Camera camera;
  late GlobalKey<DomLikeListenableState> listenableKey;
  DomLikeListenableState get _domElement => listenableKey.currentState!;
  late List<Object3D> objects;
  List<Object3D> get _objects => objects;
  Camera get _camera => camera;

  DragControls(this.objects, this.camera, this.listenableKey) : super() {
    id = Uuid().v4();
    scope = this;
    activate();
  }

  activate() {
    if( !enabled ){
      enabled = true;
      _domElement.addEventListener('pointermove', onPointerMove);
      _domElement.addEventListener('pointerdown', onPointerDown);
      _domElement.addEventListener('pointerup', onPointerCancel);
      _domElement.addEventListener('pointerleave', onPointerCancel);
    }
  }

  deactivate() {
    if( enabled ) {
      enabled = false;
      _domElement.removeEventListener('pointermove', onPointerMove);
      _domElement.removeEventListener('pointerdown', onPointerDown);
      _domElement.removeEventListener('pointerup', onPointerCancel);
      _domElement.removeEventListener('pointerleave', onPointerCancel);
    }
  }

  dispose() {
    deactivate();
  }

  getObjects() {
    return _objects;
  }

  getRaycaster() {
    return _raycaster;
  }

  onPointerMove(event) {
    if (scope.enabled == false) return;

    final dragUpdateRecord = updatePointer(event);

    _raycaster.setFromCamera(_pointer, _camera);


    if (_selected != null) {
      if (_raycaster.ray.intersectPlane(_plane, _intersection) != null ) {
        //_selected!.position.copy(_intersection.sub(_offset).applyMatrix4(_inverseMatrix));
      }

      if( _selected is DraggableObject ){
        if( moveAxis == Axis.horizontal && dragUpdateRecord.$1 != null ){
          _selected!.dispatchEvent(Event({'type': 'horizontaldragupdate', 'details': dragUpdateRecord.$1! }));
        }
        if( moveAxis == Axis.vertical && dragUpdateRecord.$2 != null ){
          _selected!.dispatchEvent(Event({'type': 'verticaldragupdate', 'details': dragUpdateRecord.$2! }));
        }
      }
    }

    if( moveAxis == Axis.horizontal && dragUpdateRecord.$1 != null ){
      scope.dispatchEvent(Event({'type': 'horizontaldragupdate', 'object': _selected, 'details': dragUpdateRecord.$1! }));
    }
    if( moveAxis == Axis.vertical && dragUpdateRecord.$2 != null ){
      scope.dispatchEvent(Event({'type': 'verticaldragupdate', 'object': _selected, 'details': dragUpdateRecord.$2! }));
    }

    // hover support

    if (event.pointerType == 'mouse' || event.pointerType == 'pen') {
      _intersections = <Intersection>[];

      _raycaster.setFromCamera(_pointer, _camera);
      _raycaster.intersectObjects(_objects, true, _intersections);

      if (_intersections.isNotEmpty) {
        var object = _intersections[0].object;

        _plane.setFromNormalAndCoplanarPoint(
            _camera.getWorldDirection(_plane.normal), _worldPosition.setFromMatrixPosition(object.matrixWorld));

        if (_hovered != object && _hovered != null) {
          scope.dispatchEvent(Event({'type': 'hoveroff', 'object': _hovered}));

          _hovered = null;
        }

        if (_hovered != object) {
          scope.dispatchEvent(Event({'type': 'hoveron', 'object': object}));

          _hovered = object;
        }
      } else {
        if (_hovered != null) {
          scope.dispatchEvent(Event({'type': 'hoveroff', 'object': _hovered}));

          _hovered = null;
        }
      }
    }
  }

  onPointerDown(event) {
    if (scope.enabled == false) return;

    final dragUpdateRecord = updatePointer(event);
    final dragStart = DragStartDetails(sourceTimeStamp: DateTime.now().difference(DateTime.fromMicrosecondsSinceEpoch(0)), globalPosition: Offset(event.clientX, event.clientY));

    _intersections = <Intersection>[];

    _raycaster.setFromCamera(_pointer, _camera);
    _raycaster.intersectObjects(_objects, true, _intersections);

    if (_intersections.isNotEmpty) {
      _selected = (scope.transformGroup == true) ? _objects[0] : _intersections[0].object;

      if (_selected != null) {
        _plane.setFromNormalAndCoplanarPoint(
            _camera.getWorldDirection(_plane.normal), _worldPosition.setFromMatrixPosition(_selected!.matrixWorld));

        if (_raycaster.ray.intersectPlane(_plane, _intersection) != null) {
          _inverseMatrix.copy(_selected!.parent?.matrixWorld ?? Matrix4()).invert();
          _offset.copy(_intersection).sub(_worldPosition.setFromMatrixPosition(_selected!.matrixWorld));
        }

        if( _selected is DraggableObject ){
          if( moveAxis == Axis.horizontal ){
            _selected!.dispatchEvent(Event({'type': 'horizontaldragstart', 'details': dragStart }));
          }
          if( moveAxis == Axis.vertical ){
            _selected!.dispatchEvent(Event({'type': 'verticaldragstart', 'details': dragStart }));
          }
        }

      }

    }

    if( moveAxis == Axis.horizontal ){
      scope.dispatchEvent(Event({'type': 'horizontaldragstart', 'object': _selected, 'details': dragStart }));
    }
    if( moveAxis == Axis.vertical ){
      scope.dispatchEvent(Event({'type': 'verticaldragstart', 'object': _selected, 'details': dragStart }));
    }

  }

  onPointerCancel(event) {
    if (scope.enabled == false) return;

    if (_selected != null) {
      if( _selected is DraggableObject ){
        if( moveAxis == Axis.horizontal ){
          _selected!.dispatchEvent(Event({'type': 'horizontaldragend' }));
        }
        if( moveAxis == Axis.vertical ){
          _selected!.dispatchEvent(Event({'type': 'verticaldragend' }));
        }
      }
      _selected = null;
    }

    if( moveAxis == Axis.horizontal ){
      scope.dispatchEvent(Event({'type': 'horizontaldragend', 'object': _selected }));
    }
    if( moveAxis == Axis.vertical ){
      scope.dispatchEvent(Event({'type': 'verticaldragend', 'object': _selected }));
    }

    moveAxis = null;
  }

  (DragUpdateDetails?, DragUpdateDetails?) updatePointer(event) {
    var box = listenableKey.currentContext?.findRenderObject() as RenderBox;
    var size = box.size;
    var local = box.globalToLocal(Offset(0, 0));

    final updatedX = (event.clientX) / size.width * 2 - 1;
    final updatedY = -(event.clientY) / size.height * 2 + 1;
    final delta = Offset(_pointer.x == 0 ? 0 : updatedX - _pointer.x, _pointer.y == 0 ? 0 : updatedY - _pointer.y);

    _pointer.x = updatedX;
    _pointer.y = updatedY;

    if( moveAxis == null ){
      if( delta.dx.abs() > delta.dy.abs() ) {
        moveAxis = Axis.horizontal;
      } else {
        moveAxis = Axis.vertical;
      }
    }

    return (
      moveAxis == Axis.horizontal && delta.dx != 0 ? DragUpdateDetails(
          delta: Offset(delta.dx, 0),
          sourceTimeStamp: DateTime.now().difference(DateTime.fromMicrosecondsSinceEpoch(0)),
          globalPosition: Offset(updatedX, updatedY),
          primaryDelta: delta.dx
      ) : null,
      moveAxis == Axis.vertical && delta.dy != 0 ? DragUpdateDetails(
          delta: Offset(0, delta.dy),
          sourceTimeStamp: DateTime.now().difference(DateTime.fromMicrosecondsSinceEpoch(0)),
          globalPosition: Offset(updatedX, updatedY),
          primaryDelta: delta.dy
      ) : null
    );
  }
}
