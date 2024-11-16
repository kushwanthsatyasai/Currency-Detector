function calculateTotal(cart, taxRate) {
    const subtotal = cart.reduce((acc, price) => acc + price, 0);
    return subtotal * (1 + taxRate);
}

function processData(input) {
    // Parse input string into cart array and tax rate
    const [cartStr, taxRateStr] = input.trim().split('\n');
    const cart = cartStr.split(' ').map(Number);
    const taxRate = parseFloat(taxRateStr);
    
    // Calculate and print the result
    console.log(calculateTotal(cart, taxRate));
} 

process.stdin.resume();
process.stdin.setEncoding("ascii");
_input = "";
process.stdin.on("data", function (input) {
    _input += input;
});

process.stdin.on("end", function () {
   processData(_input);
});