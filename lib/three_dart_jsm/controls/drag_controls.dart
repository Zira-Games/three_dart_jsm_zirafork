part of jsm_controls;

class DragControls with EventDispatcher {
  late DragControls scope;

  bool enabled = true;
  bool transformGroup = false;
  List<Intersection> _intersections = <Intersection>[];
  Object3D? _selected;
  Object3D? _hovered;

  late Camera camera;
  late GlobalKey<DomLikeListenableState> listenableKey;
  DomLikeListenableState get _domElement => listenableKey.currentState!;
  late List<Object3D> objects;
  List<Object3D> get _objects => objects;
  Camera get _camera => camera;

  DragControls(this.objects, this.camera, this.listenableKey) : super() {
    scope = this;
    activate();
  }

  activate() {
    _domElement.addEventListener('pointermove', onPointerMove);
    _domElement.addEventListener('pointerdown', onPointerDown);
    _domElement.addEventListener('pointerup', onPointerCancel);
    _domElement.addEventListener('pointerleave', onPointerCancel);
  }

  deactivate() {
    _domElement.removeEventListener('pointermove', onPointerMove);
    _domElement.removeEventListener('pointerdown', onPointerDown);
    _domElement.removeEventListener('pointerup', onPointerCancel);
    _domElement.removeEventListener('pointerleave', onPointerCancel);

    // _domElement.style.cursor = '';
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

      scope.dispatchEvent(Event({'type': 'drag', 'object': _selected}));

      return;
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

          // _domElement.style.cursor = 'auto';
          _hovered = null;
        }

        if (_hovered != object) {
          scope.dispatchEvent(Event({'type': 'hoveron', 'object': object}));

          // _domElement.style.cursor = 'pointer';
          _hovered = object;
        }
      } else {
        if (_hovered != null) {
          scope.dispatchEvent(Event({'type': 'hoveroff', 'object': _hovered}));

          // _domElement.style.cursor = 'auto';
          _hovered = null;
        }
      }
    }
  }

  onPointerDown(event) {
    if (scope.enabled == false) return;

    final dragUpdateRecord = updatePointer(event);

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
      }

      // _domElement.style.cursor = 'move';

      scope.dispatchEvent(Event({'type': 'dragstart', 'object': _selected}));
    }
  }

  onPointerCancel(event) {
    if (scope.enabled == false) return;

    if (_selected != null) {
      scope.dispatchEvent(Event({'type': 'dragend', 'object': _selected}));

      _selected = null;
    }

    // _domElement.style.cursor = _hovered ? 'pointer' : 'auto';
  }

  (DragUpdateDetails, DragUpdateDetails) updatePointer(event) {
    // var rect = _domElement.getBoundingClientRect();
    var box = listenableKey.currentContext?.findRenderObject() as RenderBox;
    var size = box.size;
    var local = box.globalToLocal(Offset(0, 0));

    final updatedX = (event.clientX - local.dx) / size.width * 2 - 1;
    final updatedY = -(event.clientY - local.dy) / size.height * 2 + 1;
    final delta = Offset(updatedX - _pointer.x, updatedY - _pointer.y);

    _pointer.x = updatedX;
    _pointer.y = updatedY;

    return (
      DragUpdateDetails(
          delta: delta,
          sourceTimeStamp: event.timeStamp,
          globalPosition: event.position,
          primaryDelta: delta.dx
      ),
      DragUpdateDetails(
          delta: delta,
          sourceTimeStamp: event.timeStamp,
          globalPosition: event.position,
          primaryDelta: delta.dy
      )
    );
  }
}
