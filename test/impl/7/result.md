# impl/7 시험 결과 — python 빌드컨텍스트(매니페스트 디렉터리) + uvicorn CMD

날짜: 2026-06-13 · 환경: macOS, bash 3.2.57, Docker · 판정: **ALL PASS**

## 버그
자동생성 Dockerfile로 빌드한 python-backend에서 `ModuleNotFoundError: No module named 'fastapi'`.
- 원인: 엔트리 `app/main.py`(중첩) → 빌드컨텍스트가 `apps/python-backend/app/`로 설정 → 부모의 `pyproject.toml`(fastapi 의존) `COPY` 누락 → `pip install .` 효과 없음 → fastapi 미설치. `python main.py`는 서버도 안 띄움.

## 수정
- python 앱 탐지를 **매니페스트 디렉터리**(`pyproject.toml`/`requirements.txt`/`setup.py`) 기준으로 변경 → 빌드컨텍스트에 매니페스트 포함.
- `_find_python_entry`: `main.py`/`app.py`/`hello.py`/`app/main.py`/… 관례로 엔트리 탐색.
- `_python_cmd_for`: fastapi/uvicorn/starlette 의존 시 ASGI 변수(`X = FastAPI(`) 탐지 → CMD `["uvicorn","<dotted>:<X>","--host","0.0.0.0","--port","8000"]` + 포트 8000. 아니면 `["python","<entry>"]`.
- Dockerfile: uvicorn 앱이면 `EXPOSE 8000` + **`RUN pip install fastapi "uvicorn[standard]"`로 서버 의존성 보장**(불완전한 pyproject 패키징에도 import 보장).
- compose: 포트 있는 앱은 `ports: ["<host>:8000"]` publish(다중 web 앱은 host 포트 자동 +i 회피).
- 매니페스트 없는 standalone 엔트리는 종전대로 `["python","<file>"]`. 매니페스트 dir 하위 중첩 엔트리는 중복 카운트 안 함(`_app_under`).

## 단위 시험 (`bash test/impl/7/run.sh`) — 14/14 PASS
빌드컨텍스트=매니페스트dir, uvicorn CMD, EXPOSE/포트, fastapi 보장 RUN, compose 포트, 엔트리 탐색, 비-fastapi→python, standalone, 중첩 중복 방지.

## 실제 docker 빌드 검증 (수동, 본 세션)
- 정상 pyproject(`[build-system]`+packages): `docker build` OK → `import fastapi,uvicorn,app.main` OK.
- **flat-layout pyproject(app/+tests/, build-system 없음, `pip install .` 실패 케이스)**: 보장 RUN 덕에 `docker build` OK → fastapi import OK. (이전이라면 ModuleNotFoundError 재발)

## 회귀 — impl/1~6=0, verify.sh=0
