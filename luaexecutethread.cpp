#include "luaexecutethread.hpp"
#include <QtCore/QString>
#include "bhj_help.hpp"
#include <QtCore/QStringList>
#include <QtCore/QDebug>
#include <QtCore/QProcess>
#include "lua.hpp"

void LuaExecuteThread::run()
{
    lua_State *L = luaL_newstate();             /* opens Lua */
    luaL_openlibs(L);        /* opens the standard libraries */

    int error = luaL_loadstring(L, "t1wrench = require('t1wrench')") || lua_pcall(L, 0, 0, 0);
    if (error) {
        emit gotSomeLog("exit", "Can't load t1wrench");
        lua_close(L);
        return;
    }

    lua_getglobal(L, "t1wrench");
    while (true) {
        QStringList script;
        mMutex.lock();
        if (mActions.length() == 0) {
            mWait.wait(&mMutex);
        }
        script = mActions.at(0);
        mActions.removeFirst();
        mMutex.unlock();
        QString func = script.at(0);
        lua_getfield(L, -1, qPrintable(func));
        script.pop_front();
        foreach (const QString& str, script) {
            lua_pushstring(L, str.toUtf8().constData());
        }
        error = lua_pcall(L, script.length(), 1, 0);
        if (error) {
            emit gotSomeLog("exit", QString().sprintf("Can't run %s", qPrintable(func)));
            lua_close(L);
            return;
        }
        lua_pop(L, 1);
    }
}

LuaExecuteThread::LuaExecuteThread(QObject* parent)
    : QThread(parent)
{

}

void LuaExecuteThread::addScript(QStringList script)
{
    mMutex.lock();
    mActions.append(script);
    mMutex.unlock();
    mWait.wakeOne();
}
