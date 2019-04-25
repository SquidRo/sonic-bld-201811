# gnmi-svr python2 wheel

GNMISVR_PY2 = gnmi_svr-0.1-py2-none-any.whl
$(GNMISVR_PY2)_SRC_PATH = $(SRC_PATH)/gnmi-svr
$(GNMISVR_PY2)_PYTHON_VERSION = 2
ifeq ($(ENABLE_ACCTON_GNMI_SERVICE), y)
    SONIC_PYTHON_WHEELS += $(GNMISVR_PY2)
endif
