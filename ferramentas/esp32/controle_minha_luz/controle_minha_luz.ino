// Controle do Minha Luz: o ESP32 vira um controle Bluetooth (gamepad).
// O jogo entende: joystick = andar, X = procurar, Start = pausar,
// A = confirmar e B = voltar (o mesmo de um controle de Xbox).
// Biblioteca: "ESP32-BLE-Gamepad" (lemmingDev), pelo Gerenciador de Bibliotecas
// da Arduino IDE (ela instala a NimBLE-Arduino junto).
// Ligações e passo a passo: ../LEIAME.md

#include <BleGamepad.h>

// ---------- Pinos (ajustados pro controle montado do grupo) ----------
// O joystick precisa de pinos do ADC1 (32 a 39): o ADC2 não funciona com o Bluetooth ligado.
// O joystick está deitado de lado no controle: o VRx do módulo virou o cima/baixo
// e o VRy virou o esquerda/direita. Por isso os dois estão trocados aqui.
const int PINO_EIXO_X = 35;       // VRy do módulo (esquerda/direita do jogo)
const int PINO_EIXO_Y = 34;       // VRx do módulo (cima/baixo do jogo)
const int PINO_PROCURAR = 25;     // botão B do controle
const int PINO_PROCURAR_2 = 32;   // clique do joystick (SW): também procura
const int PINO_CONFIRMAR = 33;    // botão A do controle
const int PINO_VOLTAR = 27;       // botão Select do controle
const int PINO_PAUSAR = 26;       // botão Start do controle
const int PINO_ENERGIA_JOYSTICK = 14;  // D14 fica em HIGH e alimenta o +5V do joystick (3,3 V)

const bool INVERTER_X = true;   // no controle do grupo o esquerda/direita sai invertido
const bool INVERTER_Y = false;  // no controle do grupo o cima/baixo já sai certo
const float ZONA_MORTA = 0.15;  // folga no centro do joystick (0 a 1)
const unsigned long DEBOUNCE_MS = 25;

// Botões numerados como o Godot espera: 1 = A, 2 = B, 3 = X, 7 = Start.
struct Botao {
  int pino;
  int pino2;  // segundo pino que aperta o mesmo botão (-1 = nenhum)
  uint8_t botao;
  bool apertado;
  unsigned long mudou;
};

Botao botoes[] = {
  {PINO_CONFIRMAR, -1, BUTTON_1, false, 0},               // A: confirmar
  {PINO_VOLTAR, -1, BUTTON_2, false, 0},                  // B: voltar (botão Select)
  {PINO_PROCURAR, PINO_PROCURAR_2, BUTTON_3, false, 0},   // X: procurar (botão B ou clique do joystick)
  {PINO_PAUSAR, -1, BUTTON_7, false, 0},                  // Start: pausar
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
  pinMode(PINO_ENERGIA_JOYSTICK, OUTPUT);
  digitalWrite(PINO_ENERGIA_JOYSTICK, HIGH);  // liga o joystick antes de medir o centro
  delay(50);
  for (Botao &b : botoes) {
    pinMode(b.pino, INPUT_PULLUP);  // botão entre o pino e o GND
    if (b.pino2 >= 0) {
      pinMode(b.pino2, INPUT_PULLUP);
    }
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
      bool apertado = digitalRead(b.pino) == LOW || (b.pino2 >= 0 && digitalRead(b.pino2) == LOW);
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
