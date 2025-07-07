pragma circom 2.1.6;

template SumCheck() {
    // 5 public inputs
    signal input a;
    signal input b;
    signal input c;
    signal input d;
    signal input e;

    // Calculate the sum
    signal sum;
    sum <== a + b + c + d + e;

    // Enforce sum == 100
    sum === 100;

    // Add dummy constraints to increase circuit size
    signal dummy1;
    signal dummy2;
    dummy1 <== a * b;
    dummy2 <== c * d;
}

component main {public [a, b, c, d, e]} = SumCheck(); 