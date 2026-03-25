from rest_framework.throttling import AnonRateThrottle, UserRateThrottle


class RegisterRateThrottle(AnonRateThrottle):
    scope = "register"


class LoginRateThrottle(AnonRateThrottle):
    scope = "login"


class WriteActionRateThrottle(UserRateThrottle):
    scope = "write_actions"
