public class Solution
{
    // 5.1 — Prefix & Suffix Arrays
    // Time Complexity: O(n) — three linear passes over the array.
    // Space Complexity: O(n) — uses two extra arrays: prefix[] and suffix[].
    public int[] ProductExceptSelfWithArrays(int[] nums)
    {
        int n = nums.Length;
        int[] prefix = new int[n];
        int[] suffix = new int[n];
        int[] result = new int[n];

        prefix[0] = 1;
        for (int i = 1; i < n; i++)
        {
            prefix[i] = prefix[i - 1] * nums[i - 1];
        }

        suffix[n - 1] = 1;
        for (int i = n - 2; i >= 0; i--)
        {
            suffix[i] = suffix[i + 1] * nums[i + 1];
        }

        for (int i = 0; i < n; i++)
        {
            result[i] = prefix[i] * suffix[i];
        }

        return result;
    }

    // 5.2 — Follow-up: O(1) Extra Space
    // Time Complexity: O(n) — two linear passes (left-to-right prefix, right-to-left suffix).
    // Space Complexity: O(1) auxiliary space (the output array pro[] does not count).
    public int[] ProductExceptSelf(int[] nums)
    {
        int n = nums.Length;
        int[] pro = new int[n];

        pro[0] = 1;

        for (int i = 1; i < n; i++)
        {
            pro[i] = nums[i - 1] * pro[i - 1];
        }

        int suffix = nums[n - 1];
        for (int i = n - 2; i >= 0; i--)
        {
            pro[i] *= suffix;
            suffix *= nums[i];
        }

        return pro;
    }
}
