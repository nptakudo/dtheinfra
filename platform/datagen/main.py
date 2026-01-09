from mimesis import Person
from mimesis.locales import Locale

person = Person(Locale.EN)

print(person.full_name())
# Output: 'Brande Sears'

# person.email(domains=["example.com"])
# # Output: 'roccelline1878@example.com'

# person.email(domains=["mimesis.name"], unique=True)
# # Output: 'f272a05d39ec46fdac5be4ac7be45f3f@mimesis.name'

# person.telephone(mask="1-4##-8##-5##3")
# # Output: '1-436-896-5213'
