class_name SkyTraffic
extends Node3D

## Deterministic looping sky traffic. Vehicles are built by WorldBuilder and
## registered with a straight, off-screen-to-off-screen flight corridor.

var _elapsed := 0.0
var _flights: Array[Dictionary] = []


func register_flight(vehicle: Node3D, centre: Vector3, direction: Vector3, half_span: float, speed: float, phase: float, bob_height: float) -> void:
	var axis := direction.normalized()
	var period := (half_span * 2.0) / maxf(speed, 0.1)
	var flight := {
		"vehicle": vehicle,
		"centre": centre,
		"axis": axis,
		"half_span": half_span,
		"period": period,
		"phase": fposmod(phase, 1.0),
		"bob_height": bob_height,
	}
	_flights.append(flight)
	vehicle.set_meta("flight_centre", centre)
	vehicle.set_meta("flight_axis", axis)
	vehicle.set_meta("flight_half_span", half_span)
	vehicle.set_meta("flight_speed", speed)
	vehicle.set_meta("flight_period", period)
	_update_flight(flight)


func _process(delta: float) -> void:
	_elapsed += delta
	for flight: Dictionary in _flights:
		_update_flight(flight)


func _update_flight(flight: Dictionary) -> void:
	var vehicle := flight.vehicle as Node3D
	if not is_instance_valid(vehicle):
		return
	var period := float(flight.period)
	var progress := fposmod(_elapsed / period + float(flight.phase), 1.0)
	var axis := flight.axis as Vector3
	var half_span := float(flight.half_span)
	var position := flight.centre as Vector3
	position += axis * lerpf(-half_span, half_span, progress)
	position.y += sin(progress * TAU * 2.0) * float(flight.bob_height)
	var side_axis := axis.cross(Vector3.UP).normalized()
	vehicle.global_transform = Transform3D(Basis(axis, Vector3.UP, side_axis), position)
	vehicle.set_meta("flight_progress", progress)
