int fib(int n) {
  if (n < 2)
    return 1;
  else
    fib(n - 1) + fib(n - 2);
}
int main() {
  return fib(6);
}
