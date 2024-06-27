# Baseline STM32CubeMX Project

This is a simple project for the STM32F750N8 microcontroller generated using STM32CubeMX.
The only user code that's been added is to [main.c](Core/Src/main.c) which blinks an LED on my particular board:
```C
HAL_GPIO_WritePin(LED_BLINK_GPIO_Port, LED_BLINK_Pin, GPIO_PIN_RESET);
HAL_Delay(1000);
HAL_GPIO_WritePin(LED_BLINK_GPIO_Port, LED_BLINK_Pin, GPIO_PIN_SET);
HAL_Delay(1000);
```
