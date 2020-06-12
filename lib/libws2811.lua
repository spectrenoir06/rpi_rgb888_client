local ffi = require("ffi")
local lib = ffi.load("lib/libws2811.so")
local class = require("lib/middleclass")

local bor    = bit.bor
local lshift = bit.lshift

ffi.cdef(
[[

	typedef struct {
		uint32_t type;
		uint32_t hwver;
		uint32_t periph_base;
		uint32_t videocore_base;
		char *desc;
	} rpi_hw_t;

	const rpi_hw_t *rpi_hw_detect(void);

	struct ws2811_device;

	typedef uint32_t ws2811_led_t;                   //< 0xWWRRGGBB

	typedef struct ws2811_channel_t {
		int gpionum;                                 //< GPIO Pin with PWM alternate function, 0 if unused
		int invert;                                  //< Invert output signal
		int count;                                   //< Number of LEDs, 0 if channel is unused
		int strip_type;                              //< Strip color layout -- one of WS2811_STRIP_xxx constants
		ws2811_led_t *leds;                          //< LED buffers, allocated by driver based on count
		uint8_t brightness;                          //< Brightness value between 0 and 255
		uint8_t wshift;                              //< White shift value
		uint8_t rshift;                              //< Red shift value
		uint8_t gshift;                              //< Green shift value
		uint8_t bshift;                              //< Blue shift value
		uint8_t *gamma;                              //< Gamma correction table
	} ws2811_channel_t;

	typedef struct ws2811_t {
		uint64_t render_wait_time;                   //< time in µs before the next render can run
		struct ws2811_device *device;                //< Private data for driver use
		const rpi_hw_t *rpi_hw;                      //< RPI Hardware Information
		uint32_t freq;                               //< Required output frequency
		int dmanum;                                  //< DMA number _not_ already in use
		ws2811_channel_t channel[2];
	} ws2811_t;

	typedef enum {
		WS2811_SUCCESS = 0,
		WS2811_ERROR_GENERIC = -1,
		WS2811_ERROR_OUT_OF_MEMORY = -2,
		WS2811_ERROR_HW_NOT_SUPPORTED = -3,
		WS2811_ERROR_MEM_LOCK = -4,
		WS2811_ERROR_MMAP = -5,
		WS2811_ERROR_MAP_REGISTERS = -6,
		WS2811_ERROR_GPIO_INIT = -7,
		WS2811_ERROR_PWM_SETUP = -8,
		WS2811_ERROR_MAILBOX_DEVICE = -9,
		WS2811_ERROR_DMA = -10,
		WS2811_ERROR_ILLEGAL_GPIO = -11,
		WS2811_ERROR_PCM_SETUP = -12,
		WS2811_ERROR_SPI_SETUP = -13,
		WS2811_ERROR_SPI_TRANSFER = -14,
		WS2811_RETURN_STATE_COUNT
	} ws2811_return_t;



	ws2811_return_t ws2811_init(ws2811_t *ws2811);                         //< Initialize buffers/hardware
	void ws2811_fini(ws2811_t *ws2811);                                    //< Tear it all down
	ws2811_return_t ws2811_render(ws2811_t *ws2811);                       //< Send LEDs off to hardware
	ws2811_return_t ws2811_wait(ws2811_t *ws2811);                         //< Wait for DMA completion
	const char * ws2811_get_return_t_str(const ws2811_return_t state);     //< Get string representation of the given return state

]])

local WS2811_TARGET_FREQ = 800000   -- Can go as low as 400000

-- 4 color R, G, B and W ordering
local SK6812_STRIP_RGBW =  0x18100800
local SK6812_STRIP_RBGW =  0x18100008
local SK6812_STRIP_GRBW =  0x18081000
local SK6812_STRIP_GBRW =  0x18080010
local SK6812_STRIP_BRGW =  0x18001008
local SK6812_STRIP_BGRW =  0x18000810
local SK6812_SHIFT_WMASK = 0xf0000000

-- 3 color R, G and B ordering
local WS2811_STRIP_RGB = 0x00100800
local WS2811_STRIP_RBG = 0x00100008
local WS2811_STRIP_GRB = 0x00081000
local WS2811_STRIP_GBR = 0x00080010
local WS2811_STRIP_BRG = 0x00001008
local WS2811_STRIP_BGR = 0x00000810

-- predefined fixed LED types
local WS2812_STRIP  = WS2811_STRIP_GRB
local SK6812_STRIP  = WS2811_STRIP_GRB
local SK6812W_STRIP = SK6812_STRIP_GRBW

local MatrixWS2811 = class("MatrixWS2811")

function MatrixWS2811:initialize(t)
	self.strip = ffi.new("struct ws2811_t")

	if t.mode == "PCM" then
		self.strip.channel[0].gpionum = 21
		self.strip.channel[0].count = t.num
		self.strip.channel[1].gpionum = 0
		self.strip.channel[1].count = 0
	elseif t.mode == "PWM" then
		self.strip.channel[0].gpionum = 12
		self.strip.channel[0].count = t.num
		self.strip.channel[1].gpionum = 0
		self.strip.channel[1].count = 0
	elseif t.mode == "PWMx2" then
		self.strip.channel[0].gpionum = 12
		self.strip.channel[0].count = t.num/2
		self.strip.channel[1].gpionum = 13
		self.strip.channel[1].count = t.num/2
	end

	if t.rgbw then
		t.type = SK6812_STRIP_GRBW
	else
		t.type = WS2811_STRIP_GRB
	end

	self.strip.freq = t.freq or WS2811_TARGET_FREQ
	self.strip.dmanum = t.dmanum or 10

	self.strip.channel[0].invert = t.inver or 0
	self.strip.channel[0].brightness = 255
	self.strip.channel[0].strip_type = t.type

	self.strip.channel[1].invert = t.inver or 0
	self.strip.channel[1].brightness = 255
	self.strip.channel[1].strip_type = t.type

	lib.ws2811_init(self.strip)
end

function MatrixWS2811:setRGB(id,r,g,b,w)
	self.strip.channel[0].leds[id] = bor(b, lshift(g,8), lshift(r,16), lshift(w or 0,24))
end

function MatrixWS2811:send()
	lib.ws2811_render(self.strip)
end

function MatrixWS2811:stop()
	lib.ws2811_fini(self.strip)
end

return MatrixWS2811
