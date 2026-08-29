#include "../Portable.h"
#include <cstdio>
#include <cmath>
#include <string>

static int wf_failures = 0;
static int wf_checks   = 0;

#define WF_CHECK(cond, msg) do { ++wf_checks;                                   \
    if (!(cond)) { ++wf_failures;                                               \
        std::printf("FAIL: %s (line %d)\n", msg, __LINE__); } } while (0)

#define WF_CHECK_NEAR(actual, expected, eps, msg) do { ++wf_checks;             \
    double _a = (actual), _e = (expected), _d = (eps);                          \
    if (!(std::fabs(_a - _e) <= _d)) { ++wf_failures;                           \
        std::printf("FAIL: %s (line %d): actual=%f expected=%f\n",              \
                    msg, __LINE__, _a, _e); } } while (0)

static int wf_report(const char *suite) {
    std::printf("[%s] %d checks, %d failures\n", suite, wf_checks, wf_failures);
    return wf_failures == 0 ? 0 : 1;
}

int main() {
    using namespace wolfox;
    const double kEps = 1e-6;

    // ---- GeoMath ----
    WF_CHECK_NEAR(haversineDistanceMeters({0,0},{0,0}), 0.0, kEps, "zero distance");
    WF_CHECK_NEAR(haversineDistanceMeters({0,0},{1,0}), 111195.0, 500.0, "1 deg latitude");
    WF_CHECK_NEAR(haversineDistanceMeters({52.52,13.405},{48.8566,2.3522}),
                  878000.0, 3000.0, "Berlin-Paris");
    WF_CHECK(haversineDistanceMeters({0,0},{10,10}) > haversineDistanceMeters({0,0},{5,5}),
             "distance monotonic");

    // ---- Movement: bearing ----
    WF_CHECK_NEAR(initialBearingDegrees({0,0},{1,0}), 0.0, 0.5, "bearing north = 0");
    WF_CHECK_NEAR(initialBearingDegrees({0,0},{0,1}), 90.0, 0.5, "bearing east = 90");

    // ---- Movement: destination point ----
    Coordinate dest = destinationPoint({0,0}, 0.0, 111195.0);
    WF_CHECK_NEAR(dest.latitude, 1.0, 0.01, "destination north 1 deg");
    WF_CHECK(dest.isValid(), "destination valid");

    // ---- Movement: interpolation ----
    Coordinate mid = interpolateGreatCircle({0,0},{2,0}, 0.5);
    WF_CHECK_NEAR(mid.latitude, 1.0, 0.01, "midpoint latitude");
    WF_CHECK_NEAR(interpolateGreatCircle({0,0},{2,0}, 0.0).latitude, 0.0, kEps, "f=0 start");
    WF_CHECK_NEAR(interpolateGreatCircle({0,0},{2,0}, 1.0).latitude, 2.0, kEps, "f=1 end");
    WF_CHECK(interpolateGreatCircle({0,0},{2,0}, 5.0).latitude <= 2.0, "f clamped high");
    WF_CHECK(interpolateGreatCircle({0,0},{2,0}, -5.0).latitude >= 0.0, "f clamped low");
    WF_CHECK(interpolateGreatCircle({0,0},{2,0}, 0.5).isValid(), "interp point valid");

    // ---- Movement: monotonic progress + clamp ----
    double prevLat = 0.0;
    for (double f = 0.25; f <= 1.0; f += 0.25) {
        Coordinate p = interpolateGreatCircle({0,0},{2,0}, f);
        WF_CHECK(p.latitude > prevLat, "progress monotonic");
        prevLat = p.latitude;
    }
    WF_CHECK_NEAR(clampFraction(-1.0), 0.0, kEps, "clamp low");
    WF_CHECK_NEAR(clampFraction(0.5), 0.5, kEps, "clamp passthrough");
    WF_CHECK_NEAR(clampFraction(2.0), 1.0, kEps, "clamp high");

    // ---- Transition rules ----
    WF_CHECK(!isModeConflict(SimulationMode::Movement, SimulationMode::None),
             "no conflict when idle");
    WF_CHECK(!isModeConflict(SimulationMode::None, SimulationMode::Movement),
             "restore default never conflicts");
    WF_CHECK(isModeConflict(SimulationMode::Movement, SimulationMode::Route),
             "movement conflicts route");
    WF_CHECK(isModeConflict(SimulationMode::Movement, SimulationMode::Random),
             "movement conflicts random");
    WF_CHECK(!isModeConflict(SimulationMode::Movement, SimulationMode::Static),
             "movement allowed over static");
    WF_CHECK(isModeConflict(SimulationMode::Random, SimulationMode::Route),
             "random conflicts route");
    WF_CHECK(isModeConflict(SimulationMode::Random, SimulationMode::Movement),
             "random conflicts movement");
    WF_CHECK(isModeConflict(SimulationMode::Route, SimulationMode::Movement),
             "route conflicts movement");
    WF_CHECK(isModeConflict(SimulationMode::Route, SimulationMode::Random),
             "route conflicts random");
    WF_CHECK(!isModeConflict(SimulationMode::Static, SimulationMode::Route),
             "static overrides route");
    WF_CHECK(!isModeConflict(SimulationMode::Static, SimulationMode::Movement),
             "static overrides movement");

    // ---- Location schema validation ----
    WF_CHECK(validateFavorite("wolfox.location/1", true, true, true, true, 52.52, 13.405),
             "valid favorite accepted");
    WF_CHECK(!validateFavorite("wrong-schema/9", true, true, true, true, 0, 0),
             "wrong schema rejected");
    WF_CHECK(!validateFavorite("wolfox.location/1", false, true, true, true, 0, 0),
             "non-string id rejected");
    WF_CHECK(!validateFavorite("wolfox.location/1", true, true, false, true, 0, 0),
             "non-numeric latitude rejected");
    WF_CHECK(!validateFavorite("wolfox.location/1", true, true, true, false, 0, 0),
             "non-numeric longitude rejected");
    WF_CHECK(!validateFavorite("wolfox.location/1", true, true, true, true, 95.0, 0),
             "out-of-range latitude rejected");
    WF_CHECK(!validateFavorite("wolfox.location/1", true, true, true, true, 0, 200.0),
             "out-of-range longitude rejected");
    WF_CHECK(validateFavorite("wolfox.location/1", true, true, true, true, -90.0, 180.0),
             "boundary coordinates accepted");
    WF_CHECK(!validateFavorite("wolfox.location/1", true, true, true, true, 90.0001, 0),
             "just-outside boundary rejected");

    return wf_report("WolFox-AllTests");
}
