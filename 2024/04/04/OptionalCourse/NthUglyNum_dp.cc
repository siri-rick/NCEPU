#include <vector>
#include <iostream>

int main() {
    int n = 0;
    scanf("%d", &n);
    std::vector<long> dp(n+1);
    dp[1] = 1;
    int i2 = 1, i3 = 1, i5 = 1;
    for (int i = 2; i <= n; i++) {
        int num2 = dp[i2] * 2, num3 = dp[i3] * 3, num5 = dp[i5] * 5;
        dp[i] = std::min(std::min(num2, num3), num5);
        if (dp[i] == num2) i2++;
        if (dp[i] == num3) i3++;
        if (dp[i] == num5) i5++;
    }
    printf("%ld\n", dp.back());

    getchar();
    return 0;
}