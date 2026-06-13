# impl/7 시험 시나리오 — python 앱 빌드컨텍스트(매니페스트 디렉터리) + uvicorn CMD

버그: 자동생성 Dockerfile로 빌드한 python-backend에서 `ModuleNotFoundError: No module named 'fastapi'`.
원인: 엔트리가 `app/main.py`(중첩)라 빌드컨텍스트가 `apps/python-backend/app/`로 잡혀, `pyproject.toml`(fastapi 의존)이 있는 부모 `apps/python-backend/`를 `COPY` 누락 → `pip install .` 스킵 → fastapi 미설치. 또한 `python main.py`는 서버를 안 띄움.

수정: python 앱은 **매니페스트 디렉터리(pyproject/requirements/setup)** 를 빌드컨텍스트로 사용. fastapi/uvicorn 의존 시 **uvicorn CMD**(`<dotted>:<asgi>`) + EXPOSE/포트. 매니페스트 없는 standalone 엔트리는 종전대로.

실행: `bash test/impl/7/run.sh`(소스 단위) + verify/impl1~6 회귀.

| # | Given | When | Then |
|---|---|---|---|
| 1 | `python-backend/`(pyproject fastapi) + `app/main.py`(`app=FastAPI()`) | `detect_run_apps` | 앱 dir = python-backend(매니페스트), entry CMD = uvicorn `app.main:app` |
| 2 | 1의 생성 결과 | Dockerfile | python-backend/Dockerfile, `COPY . .`로 pyproject 포함, EXPOSE 8000, fastapi/uvicorn 보장 RUN |
| 3 | 1의 compose | grep | `python-backend:` 서비스 + `ports:` (8000 publish) |
| 4 | 매니페스트 dir에 `app/main.py`만(엔트리 탐색) | `_find_python_entry` | `app/main.py` 반환 |
| 5 | fastapi 없는 pyproject + main.py | `_python_cmd_for` | `["python","main.py"]`, 포트 없음 |
| 6 | standalone `hello.py`(매니페스트 없음) | `detect_run_apps` | python 앱, CMD `["python","hello.py"]` |
| 7 | 매니페스트 dir 하위 중첩 엔트리 | `detect_run_apps` | 매니페스트 앱 1개만(중첩 엔트리 중복 안 됨) |
| R | 회귀 | verify + impl1~6 | 모두 PASS |
