bool isBusRouteType(int routeType) => routeType == 3 || routeType == 700;

bool isRailRouteType(int routeType) {
  return const {0, 1, 2, 5, 6, 11, 12, 100, 109}.contains(routeType);
}

bool isBusRailPair(int firstRouteType, int secondRouteType) {
  return (isBusRouteType(firstRouteType) && isRailRouteType(secondRouteType)) ||
      (isRailRouteType(firstRouteType) && isBusRouteType(secondRouteType));
}

double transferWalkingRadiusMetres({
  required int firstRouteType,
  required int secondRouteType,
  required bool sameStationName,
  required bool knownWalkingInterchange,
}) {
  if (knownWalkingInterchange) return 900;
  if (sameStationName) return 650;
  if (isBusRailPair(firstRouteType, secondRouteType)) return 600;
  return 350;
}
