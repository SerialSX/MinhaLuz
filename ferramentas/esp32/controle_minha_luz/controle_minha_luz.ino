// Controle do Minha Luz: o ESP32 vira um controle Bluetooth (gamepad).
// O jogo entende: joystick = andar, X = procurar, Start = pausar,
// A = confirmar e B = voltar (o mesmo de um controle de Xbox).
// Biblioteca: "ESP32-BLE-Gamepad" (lemmingDev), pelo Gerenciador de Bibliotecas
// da Arduino IDE (ela instala a NimBLE-Arduino junto).
// Ligações e passo a passo: ../LEIAME.md

#include <BleGamepad.h>

// ---------- Pinos (troque aqui se ligar diferente) ----------
// O joystick precisa de pinos do ADC1 (32 a 39): o ADC2 não funciona com o Bluetooth ligado.
const int PINO_EIXO_X = 34;     // VRx do joystick
const int PINO_EIXO_Y = 35;     // VRy do joystick
const int PINO_PROCURAR = 25;   // botão Procurar (o clique do joystick, SW, pode ir junto aqui)
const int PINO_CONFIRMAR = 26;  // botão Confirmar
const int PINO_VOLTAR = 27;     // botão Voltar
const int PINO_PAUSAR = 14;     // botão Pausar

const bool INVERTER_X = false;  // se "direita" andar para a esquerda, troque para true
const bool INVERTER_Y = false;  // se "cima" andar para baixo, troque para true
const float ZONA_MORTA = 0.15;  // folga no centro do joystick (0 a 1)
const unsigned long DEBOUNCE_MS = 25;

// Botões numerados como o Godot espera: 1 = A, 2 = B, 3 = X, 7 = Start.
struct Botao {
  int pino;
  uint8_t botao;
  bool apertado;
  unsigned long mudou;
};

Botao botoes[] = {
  {PINO_CONFIRMAR, BUTTON_1, false, 0},  // A: confirmar
  {PINO_VOLTAR, BUTTON_2, false, 0},     // B: voltar
  {PINO_PROCURAR, BUTTON_3, false, 0},   // X: procurar
  {PINO_PAUSAR, BUTTON_7, false, 0},     // Start: pausar
};

BleGamepad controle("Minha Luz Controle", "Minha Luz", 100);
int centroX = 2048;
int centroY = 2048;

// Média de 32 leituras com o joystick parado (não mexa nele ao ligar).
int lerCentro(int pino) {
  long soma = 0;
  for (int i = 0; i < 32; i++) {
    soma += analogRead(pino);
    delay(2);
  }
  return soma / 32;
}

// Leitura do joystick (0 a 4095) -> eixo do controle (0 a 32767, centro 16384).
int16_t eixo(int pino, int centro, bool inverter) {
  int bruto = analogRead(pino);
  float v;
  if (bruto < centro) {
    v = (bruto - centro) / (float)max(centro, 1);
  } else {
    v = (bruto - centro) / (float)max(4095 - centro, 1);
  }
  if (inverter) {
    v = -v;
  }
  if (fabs(v) < ZONA_MORTA) {
    v = 0.0;
  }
  v = constrain(v, -1.0f, 1.0f);
  return (int16_t)(16384 + v * 16383);
}

void setup() {
  for (Botao &b : botoes) {
    pinMode(b.pino, INPUT_PULLUP);  // botão entre o pino e o GND
  }
  centroX = lerCentro(PINO_EIXO_X);
  centroY = lerCentro(PINO_EIXO_Y);

  BleGamepadConfiguration config;
  config.setAutoReport(false);
  config.setControllerType(CONTROLLER_TYPE_GAMEPAD);
  config.setButtonCount(8);
  config.setHatSwitchCount(0);
  config.setWhichAxes(true, true, false, false, false, false, false, false);  // só X e Y
  config.setAxesMin(0);
  config.setAxesMax(32767);
  controle.begin(&config);
}

void loop() {
  if (controle.isConnected()) {
    controle.setX(eixo(PINO_EIXO_X, centroX, INVERTER_X));
    controle.setY(eixo(PINO_EIXO_Y, centroY, INVERTER_Y));
    unsigned long agora = millis();
    for (Botao &b : botoes) {
      bool apertado = digitalRead(b.pino) == LOW;
      if (apertado != b.apertado && agora - b.mudou >= DEBOUNCE_MS) {
        b.apertado = apertado;
        b.mudou = agora;
        if (apertado) {
          controle.press(b.botao);
        } else {
          controle.release(b.botao);
        }
      }
    }
    controle.sendReport();
  }
  delay(10);  // 100 leituras por segundo
}
