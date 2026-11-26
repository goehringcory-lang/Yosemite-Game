class_name RouteWall
extends WallSource
## Thread 2 (wall and routes): every route's pitches as v2 walls. Each route's
## plan is in data/climb/v2/routes/<id>.json (WallPlan); WallBuilder turns a
## pitch plan into the V2Wall the other systems climb on. A route with no
## file gets an automatic plan from its old ClimbProfiles spec. The frozen
## test fixture route ("v2_fixture") still gets the fixture pitch.
##
## The wall is the same every time for a route and pitch: the session seed
## isn't used, so routes can be learned and mentors can describe them.
## WallCheck proves every pitch has a climbable, protectable line.

const FIXTURE := WallSourceStub.FIXTURE
const FIXTURE_ROUTE := WallSourceStub.FIXTURE_ROUTE


func pitch_count(route: RouteData) -> int:
	if route == null or route.id == FIXTURE_ROUTE:
		return super(route)
	var plan := WallPlan.for_route(route)
	return maxi(1, (plan.get("pitches", []) as Array).size())


func build_pitch(route: RouteData, pitch: int, _seed: int) -> V2Wall:
	if route == null or route.id == FIXTURE_ROUTE:
		var f := V2Wall.from_dict(V2Data.load_json(FIXTURE))
		f.route_id = FIXTURE_ROUTE
		f.pitch = pitch
		return f
	return build(route, pitch)


## The wall for pitch [param pitch] of [param route], without a session.
static func build(route: RouteData, pitch: int) -> V2Wall:
	var plan := WallPlan.pitch(route, pitch)
	if plan.is_empty():
		return WallSourceStub.ladder(route, pitch)
	var w := WallBuilder.build(plan, route.id, pitch)
	if not w.info.has("grade"):
		w.info["grade"] = route.grade
	return w
