#include <mutex>
#include <map>
#include <thread>
#include <iostream>

namespace ClipCut {
namespace Threading {

class LockManager {
private:
    std::map<std::thread::id, std::mutex*> mActiveLocks;
    std::mutex mInternalMutex;

public:
    void acquireLock(std::mutex& mtx, const std::string& lockName) {
        std::lock_guard<std::mutex> lock(mInternalMutex);

        // Deadlock Detection Logic
        auto tid = std::this_thread::get_id();
        if (mActiveLocks.count(tid) && mActiveLocks[tid] == &mtx) {
            std::cerr << "DEADLOCK PREVENTED: " << lockName << " already held by thread " << tid << std::endl;
            return;
        }

        mtx.lock();
        mActiveLocks[tid] = &mtx;
    }

    void releaseLock(std::mutex& mtx) {
        std::lock_guard<std::mutex> lock(mInternalMutex);
        mActiveLocks.erase(std::this_thread::get_id());
        mtx.unlock();
    }
};

}
}
