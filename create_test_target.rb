#!/usr/bin/env ruby
# Script to help create test target (requires manual Xcode setup)
puts "To run tests, you need to:"
puts "1. Open CalCalculatorAiPlaygournd.xcodeproj in Xcode"
puts "2. File > New > Target > Unit Testing Bundle"
puts "3. Name: CalCalculatorTests"
puts "4. Add CalCalculatorTests folder to target membership"
puts "5. Product > Scheme > Edit Scheme > Test > Add CalCalculatorTests"
puts ""
puts "Then run: xcodebuild test -project CalCalculatorAiPlaygournd.xcodeproj -scheme CalCalculator"
