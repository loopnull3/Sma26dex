/*
 * s26locale — Termux(bionic)에서 Wine 이 한국어 로캘을 인식하게 하는 LD_PRELOAD 심.
 *
 * bionic 의 setlocale() 은 "C" / "C.UTF-8" 만 지원해서, Wine 의 init_locale() 이
 * setlocale(LC_CTYPE, NULL) 로 받은 값이 항상 "C.UTF-8" 이 된다. Wine 은 값이 정확히 "C"
 * 일 때만 LC_ALL 환경변수를 보기 때문에 LANG/LC_ALL 을 바꿔도 영어(코드페이지 1252)로 동작한다.
 *
 * 이 심은 S26_LOCALE (예: ko_KR.UTF-8) 이 설정되어 있을 때 LC_NUMERIC 을 제외한 범주의
 * "조회"(locale == NULL) 와 "환경값 적용"(locale == "") 에 S26_LOCALE 을 돌려준다.
 * 실제 libc 로캘 상태는 바꾸지 않는다.
 *
 * 빌드 (Termux): clang -shared -fPIC -O2 -o libs26locale.so s26locale.c -ldl
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <locale.h>
#include <stdlib.h>

typedef char *(*setlocale_fn)(int, const char *);

char *setlocale(int category, const char *locale)
{
    static setlocale_fn real_setlocale;
    const char *forced = getenv("S26_LOCALE");
    char *ret;

    if (!real_setlocale)
        real_setlocale = (setlocale_fn)dlsym(RTLD_NEXT, "setlocale");
    if (!real_setlocale)
        return NULL;

    if (!forced || !*forced || category == LC_NUMERIC)
        return real_setlocale(category, locale);

    if (locale == NULL)
        return (char *)forced;

    if (locale[0] == '\0') {
        ret = real_setlocale(category, locale);
        (void)ret;
        return (char *)forced;
    }
    return real_setlocale(category, locale);
}
