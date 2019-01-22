#define		I2C_SLAVE_BASE_ADDR	0xC00

;***********************************************************************
; i2c slave defines
;***********************************************************************

#define I2C_SLAVE_SSPCON_SETUP			0x36
#define	I2C_SLAVE_SSPCON_SETUP_MASK		0x2F

#define	I2C_SLAVE_STATE_BIT_DATA_NOT_ADDRESS	0x0
#define	I2C_SLAVE_STATE_BIT_READ_NOT_WRITE	0x1
#define	I2C_SLAVE_STATE_BIT_SAVED_CMD_SIZE	0x2
#define	I2C_SLAVE_STATE_BIT_READ_STATUS		0x3
#define	I2C_SLAVE_STATE_BIT_ERROR		0x7

